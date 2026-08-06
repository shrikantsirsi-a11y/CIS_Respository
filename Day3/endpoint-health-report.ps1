<#
.SYNOPSIS
Read-only endpoint health report for DWP engineers (PowerShell 5.1).

.DESCRIPTION
Collects and prints:
- System uptime
- Free disk space
- Pending reboot status (registry checks)
- Top 5 processes by memory (working set)
- Top 5 processes by CPU
- Last 5 system log errors

This script performs read-only queries only and does not change system state.
#>

# Section: Header
# What this section does:
# - Prints a timestamp and computer name so the report output is traceable.
Write-Host "==== Endpoint Health Report ===="
Write-Host ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host ("Computer : {0}" -f $env:COMPUTERNAME)
Write-Host ""

# Section: System uptime
# What this section does:
# - Reads last boot time from WMI/CIM and calculates current uptime duration.
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$lastBoot = $os.LastBootUpTime
$uptime = (Get-Date) - $lastBoot

Write-Host "[System Uptime]"
Write-Host ("Last boot time : {0}" -f $lastBoot)
Write-Host ("Uptime         : {0} days {1} hours {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
Write-Host ""

# Section: Free disk space
# What this section does:
# - Lists free and total space for all local filesystem drives.
$disks = Get-PSDrive -PSProvider FileSystem | Sort-Object Name

Write-Host "[Free Disk Space]"
$disks | Select-Object `
    Name,
    @{Name='FreeGB';Expression={[math]::Round($_.Free / 1GB, 2)}},
    @{Name='TotalGB';Expression={[math]::Round(($_.Used + $_.Free) / 1GB, 2)}},
    @{Name='UsedGB';Expression={[math]::Round($_.Used / 1GB, 2)}} |
    Format-Table -AutoSize
Write-Host ""

# Section: Pending reboot check
# What this section does:
# - Checks common registry locations used by Windows and update components
#   to indicate whether a reboot is pending.
# - Reports True if any known pending-reboot indicator exists.
# VERIFY BEFORE RUNNING: Confirm these registry paths align with your DWP image baseline/policy.
$rebootRegPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
)

$pendingReboot = $false
$pendingSignals = @()

if (Test-Path $rebootRegPaths[0]) {
    $pendingReboot = $true
    $pendingSignals += 'Component Based Servicing: RebootPending key exists'
}

if (Test-Path $rebootRegPaths[1]) {
    $pendingReboot = $true
    $pendingSignals += 'Windows Update: RebootRequired key exists'
}

$sessionMgr = Get-ItemProperty -Path $rebootRegPaths[2] -ErrorAction SilentlyContinue
if ($sessionMgr -and $sessionMgr.PendingFileRenameOperations) {
    $pendingReboot = $true
    $pendingSignals += 'Session Manager: PendingFileRenameOperations is populated'
}

Write-Host "[Pending Reboot Status]"
Write-Host ("Pending reboot: {0}" -f $pendingReboot)
if ($pendingSignals.Count -gt 0) {
    Write-Host "Signals:"
    $pendingSignals | ForEach-Object { Write-Host ("- {0}" -f $_) }
} else {
    Write-Host "Signals: none detected"
}
Write-Host ""

# Section: Top 5 processes by memory (working set)
# What this section does:
# - Retrieves running processes and shows the 5 highest by working set memory.
Write-Host "[Top 5 Processes by Memory (Working Set)]"
Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 5 `
        Id,
        ProcessName,
        @{Name='ExecutablePath';Expression={$_.Path}},
        @{Name='WorkingSetMB';Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}} |
    Format-List
Write-Host ""

# Section: Top 5 processes by CPU
# What this section does:
# - Retrieves running processes and shows the 5 highest by cumulative CPU time.
Write-Host "[Top 5 Processes by CPU]"
Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 5 `
        Id,
        ProcessName,
        @{Name='ExecutablePath';Expression={$_.Path}},
        @{Name='CPUSeconds';Expression={[math]::Round($_.CPU, 2)}} |
    Format-List
Write-Host ""

# Section: Last 5 system log errors
# What this section does:
# - Reads the Windows System event log and displays the latest 5 Error entries.
# VERIFY BEFORE RUNNING: In restricted environments, access to event logs may require elevated rights.
Write-Host "[Last 5 System Log Errors]"
Get-EventLog -LogName System -EntryType Error -Newest 5 -ErrorAction SilentlyContinue |
    Select-Object TimeGenerated, Source, EventID, Message |
    Format-Table -Wrap -AutoSize
Write-Host ""

# Section: Footer
# What this section does:
# - Marks end of output for easier copy/paste in incident notes.
Write-Host "==== End of Report ===="
