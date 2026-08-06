# Event Log Archive Script

This folder now includes `archive-event-logs.ps1`, a Windows PowerShell 5.1 script for safely archiving and clearing Windows event logs on an endpoint.

## What the script does

- Targets only logs whose newest event is older than the `-OlderThanDays` cutoff.
- Uses `3` days by default.
- Supports `-DryRun` to show how many records would be deleted without changing any logs.
- Exports each eligible log to a dated `.evtx` file before clearing it.
- Skips a log if today's archive file already exists, which makes repeated runs idempotent.
- Writes every action to a timestamped log file under the `logs` folder.
- Saves a rollback manifest under `rollback-store\sessions\<session-id>`.
- Supports a rollback mode that restores the archived `.evtx` files into `rollback-store\restored\<session-id>` for recovery and review.

## Important safety note about rollback

Windows PowerShell 5.1 can safely export and clear live event channels, but it does not provide a safe supported way to losslessly reinsert archived events back into those live channels on an active endpoint.

Because of that platform limitation, the script's rollback mode restores the exported `.evtx` archive files into a recovery folder rather than replaying them into the live event logs.

## Parameters

- `-OlderThanDays`
  Sets the age threshold in days. Only logs whose newest event is older than this value are eligible. Default: `3`.

- `-DryRun`
  Evaluates the requested logs and reports how many records would be deleted.

- `-LogName`
  One or more Windows event log names to evaluate. Default: `Application`.

- `-Rollback`
  Switches the script into rollback mode.

- `-RollbackId`
  The cleanup session id to recover from. Required when `-Rollback` is used.

- `-RollbackRoot`
  Optional root path for archive, manifest, and rollback data. Default: `rollback-store` under this folder.

- `-LogDirectory`
  Optional path for timestamped run logs. Default: `logs` under this folder.

## Examples

Dry run the default `Application` log:

```powershell
.\archive-event-logs.ps1 -DryRun
```

Dry run multiple logs older than 7 days:

```powershell
.\archive-event-logs.ps1 -DryRun -OlderThanDays 7 -LogName Application,System,Setup
```

Archive and clear the `Application` log when its newest event is older than 3 days:

```powershell
.\archive-event-logs.ps1
```

Recover archived files from a previous cleanup session:

```powershell
.\archive-event-logs.ps1 -Rollback -RollbackId 20260805-143000
```

## Output locations

- Timestamped logs: `logs\event-log-archive-YYYYMMDD-HHMMSS.log`
- Daily archives: `rollback-store\archives\YYYYMMDD\<log-name>.evtx`
- Cleanup manifests: `rollback-store\sessions\<session-id>\manifest.json`
- Rollback recovery copies: `rollback-store\restored\<session-id>`

## Idempotency behavior

If a log already has an archive file for the current day, the script skips that log and does not clear it again in the same day.

## Summary output

At the end of each run the script prints a summary that includes:

- how many logs were requested and evaluated
- how many logs and records were eligible
- how many records would be deleted in dry-run mode
- how many logs were archived and cleared
- how many logs were skipped because they were recent or already archived
- how many rollback files were prepared
- how many failures occurred