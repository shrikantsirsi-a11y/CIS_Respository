<#
.SYNOPSIS
Safely archives and clears Windows event logs on Windows PowerShell 5.1.

.DESCRIPTION
Exports event logs to dated .evtx archives before clearing them. Only logs whose
newest event is older than the configured cutoff are eligible. The script supports
dry runs, timestamped logging, idempotent archive checks, end-of-run summaries,
and a rollback mode that restores archived copies into a recovery folder.

.EXAMPLE
.\archive-event-logs.ps1 -DryRun

.EXAMPLE
.\archive-event-logs.ps1 -OlderThanDays 7 -LogName Application,Setup

.EXAMPLE
.\archive-event-logs.ps1 -Rollback -RollbackId 20260805-143000
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateRange(1, 3650)]
    [int]$OlderThanDays = 3,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [string[]]$LogName = @('Application'),

    [Parameter()]
    [switch]$Rollback,

    [Parameter()]
    [string]$RollbackId,

    [Parameter()]
    [string]$RollbackRoot,

    [Parameter()]
    [string]$LogDirectory
)

# Section: Runtime configuration
# What this section does:
# - Enforces strict scripting behavior and resolves script-relative default paths.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

if ([string]::IsNullOrWhiteSpace($RollbackRoot)) {
    $RollbackRoot = Join-Path -Path $scriptRoot -ChildPath 'rollback-store'
}

if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
    $LogDirectory = Join-Path -Path $scriptRoot -ChildPath 'logs'
}

$script:RunTimestamp = Get-Date
$script:LogFilePath = $null
$script:Summary = [ordered]@{
    LogsRequested          = 0
    LogsEvaluated          = 0
    LogsEligible           = 0
    RecordsEligible        = 0
    DryRunRecords          = 0
    LogsArchived           = 0
    LogsCleared            = 0
    RollbackPrepared       = 0
    SkippedNoRecords       = 0
    SkippedRecent          = 0
    SkippedArchiveExists   = 0
    SkippedMissingArchive  = 0
    Failed                 = 0
}

# Section: Directory creation helper
# What this section does:
# - Creates a directory when it does not already exist.
function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }
    catch {
        throw "Failed to create or validate directory '$Path': $($_.Exception.Message)"
    }
}

# Section: Logging helper
# What this section does:
# - Writes timestamped log entries to both the console and a log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = '{0} [{1}] {2}' -f $timestamp, $Level, $Message

    try {
        if ($script:LogFilePath) {
            Add-Content -LiteralPath $script:LogFilePath -Value $entry -ErrorAction Stop
        }
    }
    catch {
        Write-Host ("{0} [WARN] Failed to write to log file: {1}" -f $timestamp, $_.Exception.Message) -ForegroundColor Yellow
    }

    switch ($Level) {
        'ERROR' { Write-Host $entry -ForegroundColor Red }
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        default { Write-Host $entry }
    }
}

# Section: Log name normalization helper
# What this section does:
# - Converts an event log name into a file-system-safe name for archive files.
function ConvertTo-SafeFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $safeName = $Name
        foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
            $safeName = $safeName.Replace($invalidChar, '_')
        }

        return ($safeName -replace '[\\/]', '_')
    }
    catch {
        throw "Failed to sanitize log name '$Name': $($_.Exception.Message)"
    }
}

# Section: Manifest writer
# What this section does:
# - Saves cleanup metadata so a later rollback run can recover archived files.
function Save-RollbackManifest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Entries,

        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    try {
        $Entries | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
    }
    catch {
        throw "Failed to save rollback manifest '$ManifestPath': $($_.Exception.Message)"
    }
}

# Section: Native command wrapper
# What this section does:
# - Runs wevtutil commands and turns native failures into PowerShell exceptions.
function Invoke-WevtUtil {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$OperationDescription
    )

    try {
        $commandText = 'wevtutil.exe {0}' -f ($Arguments -join ' ')
        Write-Log -Level 'INFO' -Message ("Executing: {0}" -f $commandText)
        $output = & wevtutil.exe @Arguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($output) {
            Write-Log -Level 'INFO' -Message ($output | Out-String).Trim()
        }

        if ($exitCode -ne 0) {
            throw "wevtutil exited with code $exitCode during $OperationDescription."
        }
    }
    catch {
        throw ("Failed to {0}: {1}" -f $OperationDescription, $_.Exception.Message)
    }
}

# Section: Target log resolver
# What this section does:
# - Normalizes the requested log names and removes duplicates for the current run.
function Get-TargetLogs {
    $resolvedLogs = New-Object System.Collections.Generic.List[string]

    foreach ($requestedLog in $LogName) {
        try {
            if ([string]::IsNullOrWhiteSpace($requestedLog)) {
                continue
            }

            $trimmedName = $requestedLog.Trim()
            if (-not $resolvedLogs.Contains($trimmedName)) {
                $resolvedLogs.Add($trimmedName)
            }
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message ("Failed to resolve requested log '{0}': {1}" -f $requestedLog, $_.Exception.Message)
        }
    }

    return $resolvedLogs
}

# Section: Log metadata reader
# What this section does:
# - Reads the event log configuration and latest event for one log name.
function Get-EventLogState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $logInfo = Get-WinEvent -ListLog $Name -ErrorAction Stop
    }
    catch {
        throw "Unable to read metadata for log '$Name': $($_.Exception.Message)"
    }

    $recordCount = 0
    if ($null -ne $logInfo.RecordCount) {
        $recordCount = [int64]$logInfo.RecordCount
    }

    $latestEvent = $null
    if ($recordCount -gt 0) {
        try {
            $latestEvent = Get-WinEvent -LogName $Name -MaxEvents 1 -ErrorAction Stop
        }
        catch {
            throw "Unable to read the newest event from log '$Name': $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        LogName      = $Name
        RecordCount  = $recordCount
        LatestEvent  = $latestEvent
        IsEnabled    = $logInfo.IsEnabled
        LogMode      = $logInfo.LogMode
        MaximumSize  = $logInfo.MaximumSizeInBytes
    }
}

# Section: Archive path builder
# What this section does:
# - Builds the deterministic daily archive path used for idempotent cleanup.
function Get-ArchivePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [datetime]$ArchiveDate,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    try {
        $safeName = ConvertTo-SafeFileName -Name $Name
        $dateFolder = $ArchiveDate.ToString('yyyyMMdd')
        $archiveDirectory = Join-Path -Path (Join-Path -Path $RootPath -ChildPath 'archives') -ChildPath $dateFolder
        Ensure-Directory -Path $archiveDirectory
        return Join-Path -Path $archiveDirectory -ChildPath ($safeName + '.evtx')
    }
    catch {
        throw "Failed to build archive path for log '$Name': $($_.Exception.Message)"
    }
}

# Section: Rollback implementation
# What this section does:
# - Restores archived .evtx files from a cleanup session into a recovery folder.
# - This recovers the archived event data for inspection because live channel reinsertion
#   is not supported safely through PowerShell 5.1 on active Windows endpoints.
function Invoke-RollbackMode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionId,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $sessionPath = Join-Path -Path (Join-Path -Path $RootPath -ChildPath 'sessions') -ChildPath $SessionId
    $manifestPath = Join-Path -Path $sessionPath -ChildPath 'manifest.json'
    $restorePath = Join-Path -Path (Join-Path -Path $RootPath -ChildPath 'restored') -ChildPath $SessionId

    try {
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            throw "Rollback manifest was not found for session '$SessionId'."
        }
    }
    catch {
        throw $_
    }

    try {
        Ensure-Directory -Path $restorePath
    }
    catch {
        throw $_
    }

    try {
        $manifestEntries = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read rollback manifest '$manifestPath': $($_.Exception.Message)"
    }

    Write-Log -Level 'INFO' -Message ("Starting rollback preparation for session {0}" -f $SessionId)

    foreach ($entry in $manifestEntries) {
        try {
            if (-not (Test-Path -LiteralPath $entry.ArchivePath)) {
                $script:Summary.SkippedMissingArchive++
                Write-Log -Level 'WARN' -Message ("Archive file is missing and cannot be restored: {0}" -f $entry.ArchivePath)
                continue
            }

            $destinationFile = Join-Path -Path $restorePath -ChildPath ([System.IO.Path]::GetFileName($entry.ArchivePath))
            if (Test-Path -LiteralPath $destinationFile) {
                Write-Log -Level 'WARN' -Message ("Rollback copy already exists, skipping: {0}" -f $destinationFile)
                continue
            }

            if ($PSCmdlet.ShouldProcess($destinationFile, 'Copy archived event log into rollback restore folder')) {
                Copy-Item -LiteralPath $entry.ArchivePath -Destination $destinationFile -Force -ErrorAction Stop
                $script:Summary.RollbackPrepared++
                Write-Log -Level 'INFO' -Message ("Prepared rollback archive copy: {0}" -f $destinationFile)
            }
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message ("Failed to prepare rollback for log {0}: {1}" -f $entry.LogName, $_.Exception.Message)
        }
    }
}

# Section: Cleanup implementation
# What this section does:
# - Evaluates each requested log, performs dry-run reporting, exports eligible logs,
#   clears them, and records a manifest entry for rollback recovery.
function Invoke-EventLogCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TargetLogs,

        [Parameter(Mandatory = $true)]
        [datetime]$CutoffDate,

        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [string]$SessionId
    )

    $manifestEntries = New-Object System.Collections.Generic.List[object]
    $sessionDirectory = Join-Path -Path (Join-Path -Path $RootPath -ChildPath 'sessions') -ChildPath $SessionId

    try {
        Ensure-Directory -Path $sessionDirectory
    }
    catch {
        throw $_
    }

    foreach ($targetLog in $TargetLogs) {
        $script:Summary.LogsEvaluated++

        try {
            Write-Log -Level 'INFO' -Message ("Evaluating event log: {0}" -f $targetLog)
            $logState = Get-EventLogState -Name $targetLog

            if ($logState.RecordCount -le 0) {
                $script:Summary.SkippedNoRecords++
                Write-Log -Level 'INFO' -Message ("Skipping log with no records: {0}" -f $targetLog)
                continue
            }

            $latestTimestamp = $logState.LatestEvent.TimeCreated
            if ($latestTimestamp -gt $CutoffDate) {
                $script:Summary.SkippedRecent++
                Write-Log -Level 'INFO' -Message ("Skipping log because newer records exist. Latest event: {0} | Log: {1}" -f $latestTimestamp.ToString('yyyy-MM-dd HH:mm:ss'), $targetLog)
                continue
            }

            $script:Summary.LogsEligible++
            $script:Summary.RecordsEligible += [int64]$logState.RecordCount

            $archivePath = Get-ArchivePath -Name $targetLog -ArchiveDate $script:RunTimestamp -RootPath $RootPath
            if (Test-Path -LiteralPath $archivePath) {
                $script:Summary.SkippedArchiveExists++
                Write-Log -Level 'WARN' -Message ("Archive already exists for today, skipping cleanup to keep the run idempotent: {0}" -f $archivePath)
                continue
            }

            if ($DryRun) {
                $script:Summary.DryRunRecords += [int64]$logState.RecordCount
                Write-Log -Level 'INFO' -Message ("DRY RUN - would archive and clear {0} records from log {1}" -f $logState.RecordCount, $targetLog)
                continue
            }

            if ($PSCmdlet.ShouldProcess($targetLog, 'Archive and clear Windows event log')) {
                Invoke-WevtUtil -Arguments @('epl', $targetLog, $archivePath, '/ow:false') -OperationDescription ("archive log '$targetLog'")
                $script:Summary.LogsArchived++
                Write-Log -Level 'INFO' -Message ("Archived log to: {0}" -f $archivePath)

                Invoke-WevtUtil -Arguments @('cl', $targetLog) -OperationDescription ("clear log '$targetLog'")
                $script:Summary.LogsCleared++
                Write-Log -Level 'INFO' -Message ("Cleared log: {0}" -f $targetLog)

                $manifestEntries.Add([pscustomobject]@{
                    LogName            = $targetLog
                    ArchivePath        = $archivePath
                    RecordCount        = [int64]$logState.RecordCount
                    LatestEventTime    = $latestTimestamp.ToString('o')
                    ClearedAt          = (Get-Date).ToString('o')
                    SessionId          = $SessionId
                })
            }
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message ("Failed to process log {0}: {1}" -f $targetLog, $_.Exception.Message)
        }
    }

    if (-not $DryRun) {
        try {
            $manifestPath = Join-Path -Path $sessionDirectory -ChildPath 'manifest.json'
            Save-RollbackManifest -Entries $manifestEntries -ManifestPath $manifestPath
            Write-Log -Level 'INFO' -Message ("Saved rollback manifest: {0}" -f $manifestPath)
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message $_.Exception.Message
        }
    }
}

# Section: Summary writer
# What this section does:
# - Prints a concise summary of what the script evaluated, skipped, archived, and cleared.
function Write-Summary {
    Write-Host ''
    Write-Host '==== Event Log Archive Summary ===='
    Write-Host ("Logs requested        : {0}" -f $script:Summary.LogsRequested)
    Write-Host ("Logs evaluated        : {0}" -f $script:Summary.LogsEvaluated)
    Write-Host ("Logs eligible         : {0}" -f $script:Summary.LogsEligible)
    Write-Host ("Eligible records      : {0}" -f $script:Summary.RecordsEligible)
    Write-Host ("Dry run records       : {0}" -f $script:Summary.DryRunRecords)
    Write-Host ("Logs archived         : {0}" -f $script:Summary.LogsArchived)
    Write-Host ("Logs cleared          : {0}" -f $script:Summary.LogsCleared)
    Write-Host ("Rollback prepared     : {0}" -f $script:Summary.RollbackPrepared)
    Write-Host ("Skipped no records    : {0}" -f $script:Summary.SkippedNoRecords)
    Write-Host ("Skipped recent logs   : {0}" -f $script:Summary.SkippedRecent)
    Write-Host ("Skipped archive exists: {0}" -f $script:Summary.SkippedArchiveExists)
    Write-Host ("Skipped missing file  : {0}" -f $script:Summary.SkippedMissingArchive)
    Write-Host ("Failures              : {0}" -f $script:Summary.Failed)
    Write-Host ("Log file              : {0}" -f $script:LogFilePath)
}

# Section: Startup initialization
# What this section does:
# - Creates log and rollback locations and records the run header.
Ensure-Directory -Path $LogDirectory
Ensure-Directory -Path $RollbackRoot
Ensure-Directory -Path (Join-Path -Path $RollbackRoot -ChildPath 'sessions')
Ensure-Directory -Path (Join-Path -Path $RollbackRoot -ChildPath 'archives')
Ensure-Directory -Path (Join-Path -Path $RollbackRoot -ChildPath 'restored')

$script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath ('event-log-archive-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType File -Path $script:LogFilePath -Force | Out-Null

Write-Log -Level 'INFO' -Message '==== Event Log Archive Start ===='
Write-Log -Level 'INFO' -Message ("Computer name: {0}" -f $env:COMPUTERNAME)
Write-Log -Level 'INFO' -Message ("OlderThanDays: {0}" -f $OlderThanDays)
Write-Log -Level 'INFO' -Message ("DryRun: {0}" -f $DryRun.IsPresent)
Write-Log -Level 'INFO' -Message ("Rollback mode: {0}" -f $Rollback.IsPresent)

# Section: Main execution flow
# What this section does:
# - Routes the script into cleanup mode or rollback mode and handles top-level failures.
try {
    if ($Rollback) {
        if ([string]::IsNullOrWhiteSpace($RollbackId)) {
            throw 'Rollback mode requires -RollbackId.'
        }

        Write-Log -Level 'INFO' -Message ("Rollback session id: {0}" -f $RollbackId)
        Invoke-RollbackMode -SessionId $RollbackId -RootPath $RollbackRoot
    }
    else {
        $targetLogs = @(Get-TargetLogs)
        $script:Summary.LogsRequested = $targetLogs.Count
        $cutoffDate = $script:RunTimestamp.AddDays(-1 * $OlderThanDays)
        $sessionId = Get-Date -Format 'yyyyMMdd-HHmmss'

        Write-Log -Level 'INFO' -Message ("Cutoff date: {0}" -f $cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))
        Write-Log -Level 'INFO' -Message ("Requested logs: {0}" -f ($targetLogs -join ', '))
        Write-Log -Level 'INFO' -Message ("Rollback session id: {0}" -f $sessionId)

        Invoke-EventLogCleanup -TargetLogs $targetLogs -CutoffDate $cutoffDate -RootPath $RollbackRoot -SessionId $sessionId
    }
}
catch {
    $script:Summary.Failed++
    Write-Log -Level 'ERROR' -Message $_.Exception.Message
    throw
}
finally {
    Write-Log -Level 'INFO' -Message '==== Event Log Archive Complete ===='
    Write-Summary
}