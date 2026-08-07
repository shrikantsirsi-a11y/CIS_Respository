Version: v 1.0
Date: 07/08/2026
Status: Draft

# KB: Finance Shared Drive S: Not Mapped - L2/L3 Diagnosis and Recovery

## Background
Finance users access shared business files through drive S:, which points to \\finbridge-fs01\Finance. The mapping is delivered by Intune platform script Map-FinBridgeDrives.ps1. If this mapping fails, Finance users cannot open required working files and morning operations are blocked.

## Symptom
Engineer observes:
1. Multiple tickets from Finance users on DESKTOP-FB* devices.
2. Users can sign in to Windows but S: is missing or inaccessible.
3. Incident starts at user sign-in window, not during random daytime activity.

User reports:
1. Finance shared drive is missing from This PC.
2. Opening S: fails or path is unavailable.
3. Local apps open normally, but Finance shared files cannot be accessed.

## Root Cause
Specific technical cause:
Map-FinBridgeDrives.ps1 executed in SYSTEM context from Intune before LanmanWorkstation (Workstation service) reached running state. The script attempted UNC access to \\finbridge-fs01\Finance and failed with "Network name cannot be found", then exited with code 1 and did not retry.

Evidence that confirms this cause:
1. IntuneManagementExtension log shows script execution in SYSTEM context and exit code 1.
2. System log Event ID 7036 (Service Control Manager) shows Workstation service started after script failure timestamp.
3. System log Event ID 98 (Ntfs) shows S: not assigned.
4. System log Event ID 1500 (GroupPolicy) shows policy processing succeeded, which helps exclude domain-wide DNS/Kerberos/DC failure as primary cause.

## Detection
Use this 3-minute command path before any remediation.

1. Open PowerShell on one affected POOL-FIN-01 endpoint and run the Application log check.
Exact log location: Event Viewer (Local) > Windows Logs > Application.
Exact Event ID to search: 1000.
Exact fields to verify: TimeCreated, Id, ProviderName, Message.
Required faulting module in Message: igdumd64.dll.
Command:
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} |
Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } |
Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Pass criteria: At least one Event ID 1000 entry contains both dwm.exe and igdumd64.dll.

2. On the same affected POOL-FIN-01 endpoint, run the DWM operational check.
Exact log location: Event Viewer (Local) > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational.
Exact Event ID to search: 9009.
Exact fields to verify: TimeCreated, Id, ProviderName, Message.
Command:
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9009; StartTime=(Get-Date).AddHours(-3)} |
Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Pass criteria: Event ID 9009 appears in the same incident window as Step 1 Event 1000.

3. Run the healthy baseline comparison on an unaffected POOL-FIN-02 control endpoint.
Exact log location: Event Viewer (Local) > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational.
Exact healthy baseline Event ID: 9011 on POOL-FIN-02.
Exact fields to verify: TimeCreated, Id, ProviderName, Message.
Command:
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9011; StartTime=(Get-Date).AddHours(-3)} |
Select-Object -First 20 TimeCreated, MachineName, Id, ProviderName, Message
Pass criteria: POOL-FIN-02 shows Event 9011 and does not show the Event 1000 igdumd64.dll signature from Step 1.

4. Run the side-by-side count comparison between affected POOL-FIN-01 and unaffected POOL-FIN-02.
Exact log location: Event Viewer (Local) > Windows Logs > Application on each endpoint.
Exact Event ID compared: 1000.
Exact fields compared: Count of events where Message contains dwm.exe and igdumd64.dll.
Commands:
POOL-FIN-01:
(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' }).Count
POOL-FIN-02:
(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-3)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' }).Count
Pass criteria: POOL-FIN-01 count is greater than 0 and POOL-FIN-02 count is 0 for the same time window.

5. Confirm diagnosis before action.
Decision rule: Proceed only when all four are true.
Required confirmations:
- Application log Event 1000 with igdumd64.dll exists on affected POOL-FIN-01.
- Desktop Window Manager Operational log Event 9009 exists on affected POOL-FIN-01.
- Desktop Window Manager Operational log Event 9011 exists on unaffected POOL-FIN-02.
- POOL-FIN-01 versus POOL-FIN-02 comparison shows failure signature isolated to POOL-FIN-01.

## Resolution
Target time: 5-10 minutes to contain and restore service.

1. Open Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Option to use: Session hosts grid and column Allow new sessions.
Expected result: All POOL-FIN-01 hosts are listed with current session acceptance state.

2. Set affected POOL-FIN-01 hosts to drain mode.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select affected hosts > More > Set drain mode > Allow new sessions = No. [ELEVATED]
Azure CLI fast path:
az extension add --name desktopvirtualization
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session false
Expected result: Affected hosts show Allow new sessions = No.

3. Move new user traffic to control pool.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts > select continuity hosts > More > Set drain mode > Allow new sessions = Yes. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-02 --name <sessionHostFqdn> --allow-new-session true
Expected result: POOL-FIN-02 is open to accept new sessions.

4. Notify active users on affected POOL-FIN-01 hosts.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions > select active sessions on affected hosts > Send message.
Azure CLI fast path:
az desktopvirtualization user-session send-message --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId> --message-title "Maintenance" --message-body "Maintenance in progress. Save work and reconnect in 5 minutes."
Expected result: Message delivery returns success for targeted sessions.

5. Sign out active sessions from affected hosts after warning.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions > select affected sessions > Sign out. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization user-session delete --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId>
Expected result: Active session count on affected hosts reaches 0.

6. Reimage affected host VMs to known-good baseline.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select host > Virtual machine > Overview > Reimage. [ELEVATED]
Azure CLI fast path:
az vm reimage --resource-group <rg> --name <vmName>
Expected result: Azure activity status for each VM operation is Succeeded.

7. Restart each remediated VM.
Portal path and option: Azure Portal > Virtual machines > <vmName> > Overview > Restart. [ELEVATED]
Azure CLI fast path:
az vm restart --resource-group <rg> --name <vmName>
Expected result: VM power state returns to Running.

8. Reopen one canary host in POOL-FIN-01.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select canary host > More > Set drain mode > Allow new sessions = Yes. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <canarySessionHostFqdn> --allow-new-session true
Expected result: Exactly one POOL-FIN-01 host is open for validation logins.

9. Validate one engineer login on canary.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions.
Expected result: Session stays connected for 5 minutes with no black screen or disconnect loop.

10. Reopen remaining remediated POOL-FIN-01 hosts one-by-one.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > each remediated host > Set drain mode > Allow new sessions = Yes. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session true
Expected result: Capacity is restored with stable user logins.

## Verification
1. Verify Application Error signature is gone on remediated POOL-FIN-01 hosts.
Portal path and option: Azure Portal > Azure Monitor > Logs > select workspace linked to POOL-FIN-01 diagnostics > Time range Last 30 minutes.
KQL:
Event
| where TimeGenerated >= ago(30m)
| where EventID == 1000
| where Source == "Application Error"
| where RenderedDescription has "dwm.exe"
| where RenderedDescription has "igdumd64.dll"
| where Computer in (<remediatedHostList>)
Azure CLI fast path:
az monitor log-analytics query --workspace <workspaceId> --analytics-query "Event | where TimeGenerated >= ago(30m) | where EventID == 1000 | where Source == 'Application Error' | where RenderedDescription has 'dwm.exe' and RenderedDescription has 'igdumd64.dll'"
Pass criteria: zero rows returned.

2. Verify Desktop Window Manager failure marker is gone on remediated POOL-FIN-01 hosts.
Portal path and option: Azure Portal > Azure Monitor > Logs > same workspace > Time range Last 30 minutes.
KQL:
Event
| where TimeGenerated >= ago(30m)
| where EventID == 9009
| where Computer in (<remediatedHostList>)
Azure CLI fast path:
az monitor log-analytics query --workspace <workspaceId> --analytics-query "Event | where TimeGenerated >= ago(30m) | where EventID == 9009 | where Computer in (<remediatedHostList>)"
Pass criteria: zero rows returned.

3. Verify healthy baseline still present in control pool.
Portal path and option: Azure Portal > Azure Monitor > Logs > same workspace > Time range Last 30 minutes.
KQL:
Event
| where TimeGenerated >= ago(30m)
| where EventID == 9011
| where Computer in (<poolFin02HostList>)
Azure CLI fast path:
az monitor log-analytics query --workspace <workspaceId> --analytics-query "Event | where TimeGenerated >= ago(30m) | where EventID == 9011 | where Computer in (<poolFin02HostList>)"
Pass criteria: one or more Event 9011 rows exist for POOL-FIN-02 during the watch window.

4. Verify session stability on POOL-FIN-01.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions > filter Session state = Active.
Azure CLI fast path:
az desktopvirtualization user-session list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[?sessionState=='Active'].{user:userPrincipalName,host:sessionHostName}" -o table
Pass criteria: at least 3 unique users stay connected for 5 minutes with no reconnect loop.

5. Verify no parallel degradation on control pool.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts.
Azure CLI fast path:
az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-02 -o table
Pass criteria: POOL-FIN-02 remains open and healthy with no new disconnect spike.

## Rollback
Use rollback immediately if failures increase after reopening POOL-FIN-01 hosts.

1. Drain remediated POOL-FIN-01 hosts.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select remediated hosts > More > Set drain mode > Allow new sessions = No. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session false
Expected result: New sessions stop landing on remediated hosts within 30 seconds.

2. Sign out active sessions on drained POOL-FIN-01 hosts.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions > filter Host in remediated list > Sign out. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization user-session delete --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <sessionHostFqdn> --id <userSessionId>
Expected result: Active sessions on remediated hosts drop to 0.

3. Confirm control pool stays open for business continuity.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts > continuity hosts > Set drain mode > Allow new sessions = Yes. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-02 --name <sessionHostFqdn> --allow-new-session true
Expected result: POOL-FIN-02 accepts new connections.

4. Revert affected POOL-FIN-01 hosts to known-good image baseline.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select host > Virtual machine > Overview > Reimage. [ELEVATED]
Azure CLI fast path:
az vm reimage --resource-group <rg> --name <vmName>
Expected result: Reimage operation for each VM shows Succeeded in Azure activity.

5. Restart reverted hosts and keep them drained.
Portal path and option: Azure Portal > Virtual machines > <vmName> > Overview > Restart, then return to Host pools > POOL-FIN-01 > Session hosts and keep Allow new sessions = No. [ELEVATED]
Azure CLI fast path:
az vm restart --resource-group <rg> --name <vmName>
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <sessionHostFqdn> --allow-new-session false
Expected result: Reverted VMs are Running and still drained.

6. Reopen one reverted canary host only after verification passes.
Portal path and option: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > canary host > Set drain mode > Allow new sessions = Yes. [ELEVATED]
Azure CLI fast path:
az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name <canarySessionHostFqdn> --allow-new-session true
Expected result: One canary host is open and stable for 5 minutes.

7. Escalate as P1 if failure signature reappears after canary reopen.
Portal path and option: ITSM Major Incident workflow > assign Desktop Engineering > attach host list and verification query output.
Expected result: Engineering owns incident with full rollback evidence attached.

## Preventive
Implement all controls below.

1. Add a mandatory Intune deployment gate in change template.
Owner/Timing/Mode: Change manager, before deployment, manual gate with form enforcement.
Signal and pass/fail: Pass only when change record shows "UNC or drive mapping = Yes" and "Run using logged-on credentials = Yes"; fail if either field is missing or set to No.
If fail: Reject CAB approval and return change to release engineer for correction.
Automation note: Enforce mandatory/conditional fields in ITSM workflow [REQUIRES: ITSM form policy].

2. Harden Map-FinBridgeDrives.ps1 with service readiness guard and retry.
Owner/Timing/Mode: Image owner, before deployment, manual code update validated by automated test run.
Signal and pass/fail: Pass when script logs "LanmanWorkstation running" and exits 0 in 3/3 pilot runs; fail on any exit code 1 or missing readiness log line.
If fail: Block script promotion and return to image owner for fix and retest.
Automation note: Add CI lint/test job that fails on missing readiness/retry block [REQUIRES: script CI pipeline].

3. Add post-deployment pilot validation before broad rollout.
Owner/Timing/Mode: DWP engineer, during deployment, manual checkpoint with scripted evidence capture.
Signal and pass/fail: Pass when 3 pilot Finance endpoints each show Intune script exit code 0 and S: opens \\finbridge-fs01\Finance; fail if any pilot fails either check.
If fail: Keep POOL-FIN-01 drained and execute rollback section immediately.
Automation note: Auto-collect pilot status from endpoint logs into change ticket [REQUIRES: endpoint log collector].

4. Create weekly audit for risky Intune scripts.
Owner/Timing/Mode: DWP engineer, after deployment (weekly), automated.
Signal and pass/fail: Pass when audit report shows 0 scripts with SYSTEM context plus UNC/net use patterns; fail when count is >= 1.
If fail: Open remediation task per script with 5-business-day SLA and notify change manager.
Automation note: Scheduled Graph/API audit job and CSV evidence archive [REQUIRES: Intune API audit script].

5. Add alerting for repeated mapping failure signature.
Owner/Timing/Mode: DWP engineer, during deployment and first 60 minutes, automated.
Signal and pass/fail: Pass when alert does not trigger; fail when exit code 1 signature appears on >= 3 Finance endpoints in 15 minutes.
If fail: Auto-open major incident and page service desk lead to start rollback within 10 minutes.
Automation note: Scheduled query alert with action group [REQUIRES: central log ingestion + alert rule].

6. Add pre-deployment smoke test gate for drive mapping.
Owner/Timing/Mode: Release engineer, before deployment, manual run with scripted checks.
Signal and pass/fail: Pass when test user login maps S: and script log shows exit code 0 on both a new and existing Finance profile; fail if either profile fails.
If fail: Cancel release window and return package to image owner.

7. Add in-flight rollout monitor for event pattern drift.
Owner/Timing/Mode: DWP engineer, during deployment, automated.
Signal and pass/fail: Fail when Event ID 98 appears on >= 5 POOL-FIN-01 endpoints in 15 minutes or Event ID 1500 drops below 95% success in same window.
If fail: Freeze additional host reopen and execute rollback step 1 immediately.

8. Add post-deployment close gate tied to healthy-state proof.
Owner/Timing/Mode: Change manager, after deployment, manual approval gate.
Signal and pass/fail: Pass only when verification evidence shows zero new Event ID 98 for 30 minutes and no new Finance S: tickets; fail if either condition is not met.
If fail: Keep change in Implemented-Pending-Validation and assign DWP engineer to continue remediation.

9. Add explicit rollback trigger threshold.
Owner/Timing/Mode: Service desk lead, during and after deployment, manual trigger with optional automation.
Signal and pass/fail: Trigger rollback when either >= 5 Finance drive-access tickets in 15 minutes or >= 3 hosts show script failure exit code 1 in 15 minutes.
If fail to trigger on threshold breach: Escalate to change manager and record control breach in PIR.
Automation note: Ticket-volume plus log-threshold composite rule [REQUIRES: ITSM-alert integration].

10. Add knowledge update control after incident closure.
Owner/Timing/Mode: Service desk lead, after deployment/incident closure, manual.
Signal and pass/fail: Pass when runbook, L1 KB, and L2/L3 KB are updated and linked in incident within 2 business days; fail if any artifact is missing.
If fail: Change manager marks PIR incomplete and blocks next similar release approval.

## Related
1. RCA: Day4/RCA-finance-shared-drive-failure-20260806.md.
2. Engineer runbook: Day5/RUNBOOK-finance-shared-drive-intune-context-fix-20260806.md.
3. Incident communications: Day4/finance-shared-drive-incident-communications-20260806.md.
4. Closure note: Day4/finance-shared-drive-closure-note-20260806.md.
5. Known error record: Day4/KER-finance-shared-drive-intune-system-context-20260806.md.
6. Hypothesis analysis: Day4/shared-drive-failure-ranked-hypotheses-20260806.md.