<#
.SYNOPSIS
Safely cleans temp files for a DWP engineer on Windows PowerShell 5.1.

.DESCRIPTION
Finds files in temp locations that are older than the requested age and moves them
into a rollback store before removal from the original location. This makes cleanup
safer on Windows endpoints, supports dry runs, skips locked files, logs every action,
and allows later restoration with a rollback session id.

.EXAMPLE
.\clear-temp-directory.ps1

.EXAMPLE
.\clear-temp-directory.ps1 -DryRun -OlderThanDays 7

.EXAMPLE
.\clear-temp-directory.ps1 -IncludeWindowsTemp -OlderThanDays 3

.EXAMPLE
.\clear-temp-directory.ps1 -Rollback -RollbackId 20260805-101500
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$IncludeWindowsTemp,

    [Parameter()]
    [string[]]$TargetPath = @([System.IO.Path]::GetFullPath($env:TEMP)),

    [Parameter()]
    [switch]$Rollback,

    [Parameter()]
    [string]$RollbackId,

    [Parameter()]
    [string]$RollbackRoot,

    [Parameter()]
    [string]$LogDirectory
)

# Set strict execution behavior so the script fails fast on coding mistakes.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Resolve the script root after parameter binding so default paths work reliably in PowerShell 5.1.
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

# Create shared runtime values used by logging, rollback, and reporting.
$script:RunTimestamp = Get-Date
$script:LogFilePath = $null
$script:Summary = [ordered]@{
    Discovered = 0
    Eligible = 0
    DryRun = 0
    MovedToRollback = 0
    Restored = 0
    SkippedLocked = 0
    SkippedMissing = 0
    SkippedExisting = 0
    Failed = 0
}

# Ensure a directory exists before the script writes logs, manifests, or rollback data.
function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# Write a timestamped log line to both the console and the current log file.
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
    Add-Content -LiteralPath $script:LogFilePath -Value $entry

    switch ($Level) {
        'ERROR' { Write-Host $entry -ForegroundColor Red }
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        default { Write-Host $entry }
    }
}

# Test whether the current session is elevated before touching protected temp paths.
function Test-IsAdministrator {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Build the effective target list and avoid duplicate temp paths in the same run.
function Get-TargetDirectories {
    $resolvedPaths = New-Object System.Collections.Generic.List[string]

    foreach ($path in $TargetPath) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        try {
            $resolvedPath = [System.IO.Path]::GetFullPath($path)
            if (-not $resolvedPaths.Contains($resolvedPath)) {
                $resolvedPaths.Add($resolvedPath)
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ("Ignoring invalid target path '{0}': {1}" -f $path, $_.Exception.Message)
        }
    }

    if ($IncludeWindowsTemp) {
        if (Test-IsAdministrator) {
            $windowsTempPath = [System.IO.Path]::GetFullPath((Join-Path -Path $env:windir -ChildPath 'Temp'))
            if (-not $resolvedPaths.Contains($windowsTempPath)) {
                $resolvedPaths.Add($windowsTempPath)
            }
        }
        else {
            Write-Log -Level 'WARN' -Message 'Windows temp was requested but the session is not elevated, so it will be skipped.'
        }
    }

    return $resolvedPaths
}

# Check whether a file is currently locked so it can be skipped without stopping the run.
function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $fileStream.Close()
        return $false
    }
    catch [System.IO.IOException] {
        return $true
    }
}

# Convert an original file path into a safe rollback path that preserves the source layout.
function Get-RollbackFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,

        [Parameter(Mandatory = $true)]
        [string]$RollbackSessionPath
    )

    $driveRoot = [System.IO.Path]::GetPathRoot($OriginalPath)
    $driveName = $driveRoot.TrimEnd('\').TrimEnd(':')
    $relativePath = $OriginalPath.Substring($driveRoot.Length).TrimStart('\')
    $rollbackRootPath = Join-Path -Path (Join-Path -Path $RollbackSessionPath -ChildPath 'files') -ChildPath $driveName
    return Join-Path -Path $rollbackRootPath -ChildPath $relativePath
}

# Write the manifest for a cleanup run so the exact file set can be restored later.
function Save-RollbackManifest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Entries,

        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    $Entries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

# Restore files from a previous rollback session using the saved manifest.
function Invoke-Rollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionId,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $sessionPath = Join-Path -Path $RootPath -ChildPath $SessionId
    $manifestPath = Join-Path -Path $sessionPath -ChildPath 'manifest.json'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Rollback manifest was not found for session '$SessionId'."
    }

    $manifestEntries = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Write-Log -Level 'INFO' -Message ("Starting rollback for session {0}" -f $SessionId)

    foreach ($entry in $manifestEntries) {
        try {
            if (Test-Path -LiteralPath $entry.OriginalPath) {
                $script:Summary.SkippedExisting++
                Write-Log -Level 'WARN' -Message ("Skipping restore because the original file already exists: {0}" -f $entry.OriginalPath)
                continue
            }

            if (-not (Test-Path -LiteralPath $entry.RollbackPath)) {
                $script:Summary.SkippedMissing++
                Write-Log -Level 'INFO' -Message ("Skipping restore because the rollback copy is already absent: {0}" -f $entry.RollbackPath)
                continue
            }

            $destinationDirectory = Split-Path -Path $entry.OriginalPath -Parent
            Ensure-Directory -Path $destinationDirectory

            if ($PSCmdlet.ShouldProcess($entry.OriginalPath, 'Restore file from rollback store')) {
                Move-Item -LiteralPath $entry.RollbackPath -Destination $entry.OriginalPath -Force -ErrorAction Stop
                $script:Summary.Restored++
                Write-Log -Level 'INFO' -Message ("Restored file: {0}" -f $entry.OriginalPath)
            }
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message ("Failed to restore file {0}: {1}" -f $entry.OriginalPath, $_.Exception.Message)
        }
    }
}

# Process eligible files one by one, logging dry runs, skips, moves, and failures independently.
function Invoke-Cleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Directories,

        [Parameter(Mandatory = $true)]
        [datetime]$CutoffDate,

        [Parameter(Mandatory = $true)]
        [string]$RollbackSessionPath,

        [Parameter(Mandatory = $true)]
        [string]$RollbackSessionId
    )

    $manifestEntries = New-Object System.Collections.Generic.List[object]

    foreach ($directory in $Directories) {
        if (-not (Test-Path -LiteralPath $directory)) {
            Write-Log -Level 'WARN' -Message ("Target path not found, skipping: {0}" -f $directory)
            continue
        }

        Write-Log -Level 'INFO' -Message ("Scanning target path: {0}" -f $directory)

        try {
            $files = Get-ChildItem -LiteralPath $directory -File -Force -Recurse -ErrorAction Stop
        }
        catch {
            $script:Summary.Failed++
            Write-Log -Level 'ERROR' -Message ("Failed to enumerate files in {0}: {1}" -f $directory, $_.Exception.Message)
            continue
        }

        foreach ($file in $files) {
            $script:Summary.Discovered++

            if ($file.LastWriteTime -gt $CutoffDate) {
                continue
            }

            $script:Summary.Eligible++

            try {
                if (Test-FileLocked -Path $file.FullName) {
                    $script:Summary.SkippedLocked++
                    Write-Log -Level 'WARN' -Message ("Skipping locked file: {0}" -f $file.FullName)
                    continue
                }

                if ($DryRun) {
                    $script:Summary.DryRun++
                    Write-Log -Level 'INFO' -Message ("DRY RUN - would move to rollback session {0}: {1}" -f $RollbackSessionId, $file.FullName)
                    continue
                }

                $rollbackPath = Get-RollbackFilePath -OriginalPath $file.FullName -RollbackSessionPath $RollbackSessionPath
                $rollbackDirectory = Split-Path -Path $rollbackPath -Parent
                Ensure-Directory -Path $rollbackDirectory

                if ($PSCmdlet.ShouldProcess($file.FullName, 'Move temp file to rollback store')) {
                    Move-Item -LiteralPath $file.FullName -Destination $rollbackPath -Force -ErrorAction Stop

                    $manifestEntries.Add([pscustomobject]@{
                        OriginalPath  = $file.FullName
                        RollbackPath  = $rollbackPath
                        LastWriteTime = $file.LastWriteTime.ToString('o')
                        Length        = $file.Length
                    })

                    $script:Summary.MovedToRollback++
                    Write-Log -Level 'INFO' -Message ("Moved file to rollback store: {0}" -f $file.FullName)
                }
            }
            catch {
                $script:Summary.Failed++
                Write-Log -Level 'ERROR' -Message ("Failed to process file {0}: {1}" -f $file.FullName, $_.Exception.Message)
            }
        }
    }

    if (-not $DryRun) {
        $manifestPath = Join-Path -Path $RollbackSessionPath -ChildPath 'manifest.json'
        Save-RollbackManifest -Entries $manifestEntries -ManifestPath $manifestPath
        Write-Log -Level 'INFO' -Message ("Saved rollback manifest: {0}" -f $manifestPath)
    }
}

# Print a concise summary so the engineer can see what changed in the current run.
function Write-Summary {
    Write-Host ''
    Write-Host '==== Temp Cleanup Summary ===='
    Write-Host ("Discovered files      : {0}" -f $script:Summary.Discovered)
    Write-Host ("Eligible files        : {0}" -f $script:Summary.Eligible)
    Write-Host ("Dry run matches       : {0}" -f $script:Summary.DryRun)
    Write-Host ("Moved to rollback     : {0}" -f $script:Summary.MovedToRollback)
    Write-Host ("Restored from rollback: {0}" -f $script:Summary.Restored)
    Write-Host ("Skipped locked        : {0}" -f $script:Summary.SkippedLocked)
    Write-Host ("Skipped missing       : {0}" -f $script:Summary.SkippedMissing)
    Write-Host ("Skipped existing      : {0}" -f $script:Summary.SkippedExisting)
    Write-Host ("Failures              : {0}" -f $script:Summary.Failed)
    Write-Host ("Log file              : {0}" -f $script:LogFilePath)
}

# Initialize logging and rollback storage before any cleanup or restore work begins.
Ensure-Directory -Path $LogDirectory
Ensure-Directory -Path $RollbackRoot
$script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath ('temp-cleanup-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType File -Path $script:LogFilePath -Force | Out-Null

Write-Log -Level 'INFO' -Message '==== Temp Directory Cleanup Start ===='
Write-Log -Level 'INFO' -Message ("Computer name: {0}" -f $env:COMPUTERNAME)
Write-Log -Level 'INFO' -Message ("OlderThanDays: {0}" -f $OlderThanDays)
Write-Log -Level 'INFO' -Message ("DryRun: {0}" -f $DryRun.IsPresent)
Write-Log -Level 'INFO' -Message ("Rollback mode: {0}" -f $Rollback.IsPresent)

# Route execution into either rollback mode or cleanup mode based on the user parameters.
try {
    if ($Rollback) {
        if ([string]::IsNullOrWhiteSpace($RollbackId)) {
            throw 'Rollback mode requires -RollbackId.'
        }

        Invoke-Rollback -SessionId $RollbackId -RootPath $RollbackRoot
    }
    else {
        $cutoffDate = $script:RunTimestamp.AddDays(-1 * $OlderThanDays)
        $rollbackSessionId = Get-Date -Format 'yyyyMMdd-HHmmss'
        $rollbackSessionPath = Join-Path -Path $RollbackRoot -ChildPath $rollbackSessionId
        if (-not $DryRun) {
            Ensure-Directory -Path $rollbackSessionPath
        }

        $directories = Get-TargetDirectories
        Write-Log -Level 'INFO' -Message ("Cutoff date: {0}" -f $cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))
        Write-Log -Level 'INFO' -Message ("Rollback session id: {0}" -f $rollbackSessionId)

        Invoke-Cleanup -Directories $directories -CutoffDate $cutoffDate -RollbackSessionPath $rollbackSessionPath -RollbackSessionId $rollbackSessionId
    }
}
catch {
    $script:Summary.Failed++
    Write-Log -Level 'ERROR' -Message $_.Exception.Message
    throw
}
finally {
    Write-Log -Level 'INFO' -Message '==== Temp Directory Cleanup Complete ===='
    Write-Summary
}