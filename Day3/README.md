# Temp Cleanup Script

This folder contains `clear-temp-directory.ps1`, a Windows PowerShell 5.1 script for safely cleaning temp files on a Windows endpoint.

## What the script does

- Cleans files from the current user's temp folder by default.
- Optionally includes the Windows temp folder with `-IncludeWindowsTemp`.
- Only targets files older than the number of days supplied with `-OlderThanDays`.
- Supports `-DryRun` to print the files that would be moved out of the temp locations.
- Skips locked files and logs the error without stopping the run.
- Writes every action to a timestamped log file under the `logs` folder.
- Moves files into a rollback store before removal from the original path.
- Supports restoring a previous cleanup by using `-Rollback` and `-RollbackId`.
- Is idempotent because files already moved are not processed again in later runs, and repeated rollbacks safely skip files that are already restored.

## Parameters

- `-OlderThanDays`
  Controls the file age filter. Default: `0`.
  `0` means files with a last write time older than the current run time are eligible.

- `-DryRun`
  Shows the files that would be processed and writes those actions to the log without moving any files.

- `-IncludeWindowsTemp`
  Adds `%WINDIR%\Temp` to the target list when the session is elevated.

- `-TargetPath`
  Optional list of target folders. Default: the current user's `%TEMP%` folder.

- `-Rollback`
  Switches the script into restore mode.

- `-RollbackId`
  The rollback session id to restore. Required when `-Rollback` is used.

- `-RollbackRoot`
  Optional path for rollback storage. Default: `rollback-store` under this folder.

- `-LogDirectory`
  Optional path for log files. Default: `logs` under this folder.

## Examples

Dry run against the current user's temp folder:

```powershell
.\clear-temp-directory.ps1 -DryRun
```

Clean files older than 7 days from the user temp folder and Windows temp:

```powershell
.\clear-temp-directory.ps1 -OlderThanDays 7 -IncludeWindowsTemp
```

Dry run against a custom target folder:

```powershell
.\clear-temp-directory.ps1 -DryRun -TargetPath 'C:\Temp'
```

Restore files from a previous cleanup session:

```powershell
.\clear-temp-directory.ps1 -Rollback -RollbackId 20260805-101500
```

## Log and rollback output

- Logs are written to the `logs` folder with names like `temp-cleanup-YYYYMMDD-HHMMSS.log`.
- Rollback data is written to `rollback-store\<session-id>`.
- Each cleanup session saves a `manifest.json` file that is used for restoration.
- The log records the rollback session id created during the cleanup run.

## Notes

- The script only targets files, not directories.
- Locked files are skipped and logged as warnings.
- If `-IncludeWindowsTemp` is used without elevation, the Windows temp path is skipped and logged.