<#
    .SYNOPSIS
        System health report script.

    .DESCRIPTION
        Purpose : Generates a quick, read-only health snapshot of the local machine -
                  computer info, free disk space on C:, top 5 memory-consuming processes,
                  the last 10 System-log error events, and any stale (unused 90+ days)
                  local user profiles.
        Author  : (unknown - inherited script)
        Usage   : Run directly in a PowerShell console or ISE:
                      .\inhrited.ps1
                  No parameters are required. Run as a user with permission to read
                  event logs and user profile information (local admin recommended).
        Notes   : This script is read-only - it does not change any system settings.
#>

# Get general computer system details (name, memory, domain, etc.)
$computerSystemInfo = Get-CimInstance Win32_ComputerSystem

# Get the amount of free space (in bytes) on the C: drive
$freeDiskSpaceBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Get the top 5 processes using the most physical memory (working set)
$topProcessesByMemory = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Get the 10 most recent System log events and keep only the errors (Level 2)
$recentErrorEvents = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Get local user profiles that are not special system profiles and have not been used in over 90 days
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# Print the computer name and total physical memory
Write-Host $computerSystemInfo.Name $computerSystemInfo.TotalPhysicalMemory

# Print the free disk space on C:, rounded to 2 decimal places, in GB
Write-Host ([math]::Round($freeDiskSpaceBytes / 1GB, 2)) 'GB free'

# Print the name and working-set memory of each of the top 5 processes
$topProcessesByMemory | ForEach-Object { Write-Host $_.Name $_.WS }

# Print the timestamp and message of each recent error event
$recentErrorEvents | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# If any stale user profiles were found, print how many
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }