Version: v 1.0
Date: 07/08/2026
Status: Draft

# KB: POOL-FIN-01 Black Screen and Post-Login Disconnect - L2/L3 Diagnosis and Recovery

## Background
Azure Virtual Desktop for Finance provides the user workspace required for start-of-day operations. POOL-FIN-01 carries a large share of Finance interactive logins. A failure during desktop initialization in this pool causes immediate productivity impact, high reconnect churn, and rapid service desk queue growth. Fast isolation and controlled recovery are required to avoid business disruption.

## Symptom
Engineer observations:
1. Incident spike is scoped to POOL-FIN-01.
2. POOL-FIN-02 remains healthy during the same time window.
3. New sessions on some POOL-FIN-01 hosts show login success followed by disconnect.

User reports:
1. Black screen immediately after entering credentials.
2. Session disconnects within seconds after sign-in.
3. Reconnect loop after multiple attempts.

## Root Cause
Specific technical cause:
A graphics stack regression introduced by the overnight POOL-FIN-01 update causes dwm.exe to crash in igdumd64.dll during post-auth desktop initialization.

Evidence that confirms the cause:
1. Event 21 in TerminalServices-LocalSessionManager shows logon success.
2. Event 1000 in Application log shows Application Error for dwm.exe with faulting module igdumd64.dll and exception code 0xc0000005.
3. Event 9009 in Desktop Window Manager log shows DWM exit/failure.
4. Event 40 in TerminalServices-LocalSessionManager shows immediate disconnect.
5. Control comparison: POOL-FIN-02 shows Event 21 and Event 9011 with no matching Event 1000 pattern.

## Detection
Confirm this diagnosis in under 3 minutes before remediation.

1. Open Azure Portal path: Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts, then copy one affected VM name.
Exact log location: Windows Event Log on that VM, Application log.
Fields to check later: Id, ProviderName, TimeCreated, MachineName, Message.
Success criteria: You have one POOL-FIN-01 VM name ready for command checks.

2. Connect to that VM and run this PowerShell command for Application log Event 1000.
Exact log location: Application log.
Exact event ID: 1000.
Required faulting module: igdumd64.dll.
Command:
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Fields to confirm: Id must be 1000, Message must include dwm.exe and igdumd64.dll.
Success criteria: One or more matching Event 1000 entries on POOL-FIN-01 VM.

3. On the same POOL-FIN-01 VM, run this PowerShell command for DWM crash marker.
Exact log location: Microsoft-Windows-Desktop Window Manager/Operational log.
Exact event ID: 9009.
Command:
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9009; StartTime=(Get-Date).AddHours(-3)} | Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Fields to confirm: Id must be 9009 and Message indicates DWM exit/failure.
Success criteria: Event 9009 appears in same incident window as Event 1000.

4. Run this PowerShell command on a control VM from POOL-FIN-02.
Exact log location: Microsoft-Windows-Desktop Window Manager/Operational log.
Healthy baseline event ID: 9011 on POOL-FIN-02 (unaffected control).
Command:
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9011; StartTime=(Get-Date).AddHours(-3)} | Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Fields to confirm: Id must be 9011 on POOL-FIN-02 control VM.
Success criteria: POOL-FIN-02 shows Event 9011 while affected POOL-FIN-01 shows Event 9009 pattern.

5. Complete the required pool comparison using two quick commands.
Exact log location: Application log on each VM.
Exact event IDs compared: 1000 on POOL-FIN-01 versus POOL-FIN-02.
Commands:
POOL-FIN-01 check:
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Measure-Object
POOL-FIN-02 check:
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Measure-Object
Fields to compare: Count value from each command.
Success criteria: POOL-FIN-01 Count is greater than 0 and POOL-FIN-02 Count is 0 for the same time window.

6. Optional fast portal confirmation for ticket evidence.
Exact log location: Azure Monitor -> Logs -> Event table.
Fields to include in evidence: TimeGenerated, Computer, EventID, Source, RenderedDescription.
Success criteria: Query output supports the same Event 1000 and host pattern already confirmed by VM log checks.

## Resolution
Execute in order. Target execution time: 5-10 minutes for containment and recovery start.

1. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts.
Option to use: Session hosts grid, column Allow new sessions.
Expected result: You can see all POOL-FIN-01 session hosts and current Allow new sessions values.

2. Set Allow new sessions = No for affected hosts using More -> Set drain mode. [ELEVATED]
CLI fast path:
az extension add --name desktopvirtualization
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session false
Expected result: Affected hosts show Allow new sessions = No.

3. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions.
Option to use: Filter by Session state = Active and Session host in affected list.
Expected result: Only active user sessions on affected hosts are displayed.

4. Send maintenance warning from User sessions -> Send message.
CLI fast path:
az desktopvirtualization user-session send-message --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId> --message-title "Maintenance" --message-body "Maintenance in progress. Save work and reconnect in 5 minutes."
Expected result: Message status returns success for each targeted session.

5. Sign out active sessions from User sessions -> Sign out. [ELEVATED]
CLI fast path:
az desktopvirtualization user-session delete --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId>
Expected result: Active session count on affected hosts reaches 0.

6. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> select host -> Virtual machine -> Overview.
Option to use: Reimage (if available by policy) or approved replace workflow.
CLI fast path (reimage):
az vm reimage --resource-group <rg> --name <vmName>
Expected result: Activity log for each VM shows operation status Succeeded.

7. Restart each remediated VM from Virtual machine -> Overview -> Restart. [ELEVATED]
CLI fast path:
az vm restart --resource-group <rg> --name <vmName>
Expected result: VM power state returns to Running.

8. Reopen one canary host only in Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> select canary host -> Allow new sessions = Yes. [ELEVATED]
CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <canarySessionHostFqdn> --allow-new-session true
Expected result: Exactly one remediated host is open.

9. Perform one validation login to the canary host.
Expected result: Desktop loads in under 60 seconds and remains connected for 5 minutes.

10. Reopen remaining remediated hosts one-by-one from Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> Allow new sessions = Yes. [ELEVATED]
CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session true
Expected result: Capacity returns with no immediate recurrence.

## Verification
1. Open Azure Portal -> Azure Monitor -> Logs -> select the workspace from POOL-FIN-01 Diagnostic settings.
Option to use: Time range = Last 30 minutes.
KQL:
Event
| where TimeGenerated >= ago(30m)
| where EventID == 1000
| where Source == "Application Error"
| where RenderedDescription has "dwm.exe"
| where RenderedDescription has "igdumd64.dll"
| where Computer in (<remediatedHostList>)
CLI fast path:
az monitor log-analytics query --workspace <workspaceId> --analytics-query "Event | where TimeGenerated >= ago(30m) | where EventID == 1000 | where Source == 'Application Error' | where RenderedDescription has 'dwm.exe' and RenderedDescription has 'igdumd64.dll'"
Pass criteria: Zero rows returned.

2. In Azure Portal -> Azure Monitor -> Logs -> same workspace, run DWM failure check.
Option to use: Time range = Last 30 minutes.
KQL:
Event
| where TimeGenerated >= ago(30m)
| where EventID == 9009
| where Computer in (<remediatedHostList>)
CLI fast path:
az monitor log-analytics query --workspace <workspaceId> --analytics-query "Event | where TimeGenerated >= ago(30m) | where EventID == 9009"
Pass criteria: Zero rows returned on remediated hosts.

3. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions.
Option to use: Filter Session state = Active.
CLI fast path:
az desktopvirtualization user-session list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[?sessionState=='Active'].{user:userPrincipalName,host:sessionHostName}" -o table
Pass criteria: At least 3 unique users remain connected for 5 minutes without reconnect loop.

4. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts and compare stability baseline.
Option to use: Confirm control pool remains open and healthy while POOL-FIN-01 errors are cleared.
Pass criteria: No simultaneous spike in POOL-FIN-02 failures during the same 30-minute watch window.

## Rollback
Use immediately if failures increase after reopening remediated hosts.

1. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> select remediated hosts -> More -> Set drain mode -> Allow new sessions = No. [ELEVATED]
CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session false
Expected result: New sessions stop landing on remediated hosts within 30 seconds.

2. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions -> filter Host = remediated hosts -> Sign out. [ELEVATED]
CLI fast path:
az desktopvirtualization user-session delete --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId>
Expected result: Active sessions on remediated hosts drop to 0.

3. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts -> select continuity hosts -> Set drain mode -> Allow new sessions = Yes. [ELEVATED]
CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-02 --name <sessionHostFqdn> --allow-new-session true
Expected result: POOL-FIN-02 accepts new user connections.

4. Revert failed POOL-FIN-01 hosts to known-good baseline from Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> select host -> Virtual machine -> Reimage or approved replace workflow. [ELEVATED]
CLI fast path:
az vm reimage --resource-group <rg> --name <vmName>
Expected result: Activity log for each reverted VM shows Succeeded.

5. Restart reverted VMs from Virtual machine -> Overview -> Restart, and keep Allow new sessions = No until canary passes. [ELEVATED]
CLI fast path:
az vm restart --resource-group <rg> --name <vmName>
Expected result: Reverted VMs are Running but drained.

6. Reopen one reverted canary host only, then run Verification steps 1-3 before opening remaining hosts. [ELEVATED]
CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <canarySessionHostFqdn> --allow-new-session true
Expected result: Service stabilizes without reintroducing the failure pattern.

## Preventive
Implement all controls below to prevent recurrence.

1. Canary release gate in image pipeline.
Owner/Timing/Mode: Release engineer, during deployment, automated [REQUIRES: pipeline stage gate + canary ring tagging].
Pass/Fail signal: Pass if canary (10 percent hosts, 60 minutes) stays at EventID 1000 <= 2 per host per 30 minutes and EventID 9009 <= 1 per host per 30 minutes.
If fail: Change manager blocks full rollout and DWP engineer executes rollback steps 1-3 immediately.

2. Automated crash alert in Azure Monitor.
Owner/Timing/Mode: DWP engineer, during deployment and first 60 minutes after deployment, automated [REQUIRES: Azure Monitor alert rule + action group].
Pass/Fail signal: Pass if alert does not trigger; fail when EventID 1000 with dwm.exe and igdumd64.dll appears on >= 3 hosts in 15 minutes.
If fail: Auto-create Sev-2 incident and pause host reopen actions until verification returns zero new hits.

3. Automated disconnect-chain alert.
Owner/Timing/Mode: DWP engineer, during deployment and first 60 minutes after deployment, automated [REQUIRES: KQL scheduled query alert].
Pass/Fail signal: Fail when EventID 21 and EventID 40 occur on same Computer within 2 minutes on >= 2 hosts in 10 minutes.
If fail: Route incident to service desk lead and trigger immediate drain on newly changed hosts.

4. Promotion readiness test.
Owner/Timing/Mode: Image owner, before deployment, automated [REQUIRES: synthetic login test runner].
Pass/Fail signal: Pass if 20-minute test shows login success rate >= 99 percent, median desktop load <= 60 seconds, and zero EventID 1000/9009.
If fail: Release engineer rejects image promotion and returns build to image owner for correction and retest.

5. Mandatory rollback checkpoint.
Owner/Timing/Mode: Change manager, before deployment, manual.
Pass/Fail signal: Pass only if change record contains baseline ID, rollback owner role, rollback CLI commands, and trigger thresholds.
If fail: CAB approval is denied; automation approach: enforce required fields in ITSM change template [REQUIRES: ITSM form policy].

6. Post-deployment validation gate.
Owner/Timing/Mode: DWP engineer, after deployment (first 30 minutes), manual with script assist.
Pass/Fail signal: Pass only if EventID 1000 and 9009 counts are zero on remediated hosts, at least 3 user sessions stay connected 5 minutes, and POOL-FIN-02 remains stable.
If fail: Keep POOL-FIN-01 hosts drained and run rollback section before closing the change.

7. Rollback trigger threshold control.
Owner/Timing/Mode: Service desk lead with DWP engineer, during and after deployment, automated trigger + manual execution [REQUIRES: alert-to-ITSM bridge].
Pass/Fail signal: Trigger rollback when either >= 5 black-screen tickets in 15 minutes or EventID 1000 signature appears on >= 3 hosts in 15 minutes.
If fail: Auto-open Major Incident and require rollback start within 10 minutes of trigger.

8. Knowledge update control.
Owner/Timing/Mode: Service desk lead, after deployment and after incident closure, manual.
Pass/Fail signal: Pass only when runbook, L1 KB, and L2/L3 KB are updated within 2 business days and linked in the closed incident.
If fail: Change manager marks PIR incomplete and blocks next similar image rollout until documentation updates are complete.

## Related
1. RCA document: Day4 RCA for POOL-FIN-01 black screen incident on 2026-08-06.
2. Engineer runbook: Day5 POOL-FIN-01 black screen recovery runbook.
3. Communication artifacts: Day4 POOL-FIN-01 closure note and end-user communications.
4. Known error records: Day4 AVD black screen analysis and ranked hypothesis notes.
