Version: v 1.0
Date: 07/08/2026
Status: Draft

# L2/L3 KB - Diagnose and Recover Single-User AD Lockout from Multi-Source Credential Replay

## Background
This flow covers a single-user sign-in failure where Active Directory lockout is triggered by repeated bad password attempts from more than one source. In this incident pattern, one source is the user workstation and another is a second device or service replaying old credentials.

Why this matters:
- Unlocking the account alone causes repeat lockout if replay sources are not removed first.
- Fast source isolation reduces repeat incidents and user downtime.
- Correct evidence capture improves audit quality and escalation speed.

## Symptom
Engineer observes:
- Security failures and lockout events for one user in Domain Controller Security logs.
- Repeated failures from workstation DESKTOP-FB022 and another source IP (10.10.8.112).

User reports:
- "I cannot sign in."
- "My account says locked" or repeated password prompts.

## Root Cause
Specific technical cause:
- AD account lockout caused by bad password replay from multiple sources using stale stored credentials.

Evidence that confirms this cause:
- Event ID 4776 with error 0xC000006A (wrong password) for FINBRIDGE\\cthompson from DESKTOP-FB022.
- Event ID 4625 (interactive bad password) repeated from DESKTOP-FB022.
- Event ID 4740 account lockout for FINBRIDGE\\cthompson with Caller Computer Name DESKTOP-FB022.
- Event ID 4771 with failure code 0x18 (wrong password) from Source Network Address 10.10.8.112.
- Recovery markers after fix: Event ID 4722 (account enabled) and Event ID 4624 (interactive success).

## Detection
Confirm this exact issue before remediation.

1. Open Event Viewer on POOL-FIN-01 and go to Event Viewer (Local) > Windows Logs > Application. [ELEVATED]
   What to look for: You are in Application log (not Security/System).

2. In Application log, select Action > Filter Current Log and set Event IDs to 1000,9009. [ELEVATED]
   What to look for: Filtered view shows Event 1000 and/or Event 9009 entries in the incident time window.

3. Open the latest Event ID 1000 in Application log and read General tab field Faulting module name. [ELEVATED]
   What to look for: Faulting module name = igdumd64.dll.

4. Open the latest Event ID 9009 in Application log and read General tab fields Computer and Time Created. [ELEVATED]
   What to look for: Computer = POOL-FIN-01 and timestamp aligns with reported failure window.

5. Run this PowerShell command on POOL-FIN-01: Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=(Get-Date).AddHours(-4)} | Select-Object TimeCreated,Id,MachineName,ProviderName,Message | Format-List. [ELEVATED]
   What to look for: Output contains Event 1000 entries referencing igdumd64.dll and Event 9009 entries in the same period.

6. Open Event Viewer on POOL-FIN-02 and go to Event Viewer (Local) > Windows Logs > Application. [ELEVATED]
   What to look for: Baseline control system Application log is open.

7. In POOL-FIN-02 Application log, filter Event ID to 9011. [ELEVATED]
   What to look for: Event 9011 is present as unaffected control baseline.

8. Run this PowerShell command on POOL-FIN-02: Get-WinEvent -FilterHashtable @{LogName='Application'; Id=9011; StartTime=(Get-Date).AddHours(-4)} | Select-Object TimeCreated,Id,MachineName,ProviderName,Message | Format-List. [ELEVATED]
   What to look for: Output confirms Event 9011 on POOL-FIN-02 during the same comparison window.

9. Run this comparison command on any admin host: $bad=(Get-WinEvent -ComputerName 'POOL-FIN-01' -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=(Get-Date).AddHours(-4)}).Count; $good=(Get-WinEvent -ComputerName 'POOL-FIN-02' -FilterHashtable @{LogName='Application'; Id=9011; StartTime=(Get-Date).AddHours(-4)}).Count; "POOL-FIN-01 bad events=$bad; POOL-FIN-02 baseline events=$good". [ELEVATED]
   What to look for: POOL-FIN-01 shows Event 1000/9009 while POOL-FIN-02 shows baseline Event 9011.

Only continue when Event 1000 with igdumd64.dll and Event 9009 are confirmed on POOL-FIN-01, and Event 9011 is confirmed on POOL-FIN-02.

## Resolution
Use this fast path when POOL-FIN-01 is the affected pool and POOL-FIN-02 is healthy baseline.

1. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts. [ELEVATED]
   Expected result: FIN01 session host list is visible.

2. Select session host FIN01-* that matches the failing user connection. [ELEVATED]
   Expected result: Session host details pane opens.

3. Select Drain mode = On for FIN01-* in Host pool path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-* > Drain mode. [ELEVATED]
   Expected result: New user sign-ins stop on this host.

4. Run Azure CLI to enable drain mode quickly: az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <fin01-host-fqdn> --allow-new-session false. [ELEVATED]
   Expected result: Command returns allowNewSession = false.

5. Open Azure portal path Azure Portal > Virtual machines > FIN01-* > Settings > Extensions + applications and verify AVD agent extensions show Provisioning succeeded. [ELEVATED]
   Expected result: No failed extension state.

6. Open Azure portal path Azure Portal > Virtual machines > FIN01-* > Settings > Disks and capture the current OS disk snapshot name/time before image action. [ELEVATED]
   Expected result: Recovery point metadata is recorded.

7. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-* > Remove. [ELEVATED]
   Expected result: FIN01-* is removed from host pool registration.

8. Run Azure CLI to reimage the host quickly from current image: az vm reimage --resource-group <rg> --name <fin01-vm-name>. [ELEVATED]
   Expected result: Reimage job starts successfully.

9. Run Azure CLI to wait for reimage completion: az vm wait --resource-group <rg> --name <fin01-vm-name> --updated. [ELEVATED]
   Expected result: Command exits with success when VM update completes.

10. Run Azure CLI to re-register host to pool: az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <fin01-host-fqdn> --allow-new-session true. [ELEVATED]
    Expected result: Host allows new sessions again.

11. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts and confirm FIN01-* status = Available. [ELEVATED]
    Expected result: Session host is healthy and accepting sessions.

## Verification
1. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-* and confirm Status = Available and Drain mode = Off. [ELEVATED]
   Success criteria: Host shows Available and accepts new sessions.

2. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Monitoring > Insights > Connections and filter last 30 minutes for FIN01-*. [ELEVATED]
   Success criteria: Connection successes present and no spike in failures.

3. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts and confirm at least one POOL-FIN-02 host stayed Available during incident window (control comparison). [ELEVATED]
   Success criteria: POOL-FIN-02 remained healthy as unaffected baseline.

4. Run Azure CLI verification command: az desktopvirtualization session-host show --resource-group <rg> --host-pool-name POOL-FIN-01 --name <fin01-host-fqdn> --query "{allowNewSession:properties.allowNewSession,status:properties.status,lastHeartBeat:properties.lastHeartBeat}". [ELEVATED]
   Success criteria: allowNewSession=true and status=Available.

5. Run Azure CLI check for recent VM power/runtime state: az vm get-instance-view --resource-group <rg> --name <fin01-vm-name> --query "instanceView.statuses[].displayStatus". [ELEVATED]
   Success criteria: VM reports running/provisioning succeeded states only.

## Rollback
Use only if remediation increases impact.

1. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-* and set Drain mode = On. [ELEVATED]
   Expected result: No new sessions land on unstable host.

2. Run Azure CLI to enforce rollback drain state: az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --session-host-name <fin01-host-fqdn> --allow-new-session false. [ELEVATED]
   Expected result: allowNewSession=false is returned.

3. Open Azure portal path Azure Portal > Virtual machines > FIN01-* > Settings > Disks > OS disk > Create snapshot and select the pre-change recovery point captured in resolution step 6. [ELEVATED]
   Expected result: Snapshot restore workflow is started from known-good point.

4. Run Azure CLI command to deallocate VM: az vm deallocate --resource-group <rg> --name <fin01-vm-name>. [ELEVATED]
   Expected result: VM power state changes to Stopped (deallocated).

5. Run Azure CLI command to create rollback OS disk from snapshot: az disk create --resource-group <rg> --name <fin01-vm-name>-osdisk-rollback --source <snapshot-resource-id>. [ELEVATED]
   Expected result: New managed disk is created from snapshot.

6. Run Azure CLI command to attach rollback OS disk to VM: az vm update --resource-group <rg> --name <fin01-vm-name> --os-disk <fin01-vm-name>-osdisk-rollback. [ELEVATED]
   Expected result: VM configuration points to rollback OS disk.

7. Run Azure CLI command to start VM: az vm start --resource-group <rg> --name <fin01-vm-name>. [ELEVATED]
   Expected result: VM returns to Running state.

8. Open Azure portal path Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts and confirm FIN01-* is either Unavailable (expected during rollback) or Available after completion. [ELEVATED]
   Expected result: Host state matches rollback phase and is controlled.

9. Run Azure CLI post-rollback verification: az desktopvirtualization session-host show --resource-group <rg> --host-pool-name POOL-FIN-01 --name <fin01-host-fqdn> --query "{allowNewSession:properties.allowNewSession,status:properties.status}". [ELEVATED]
   Expected result: Host remains drained until incident lead approves reopen.

10. Open ITSM path ServiceNow > Incident > Create New and raise P1 to Identity Engineering with portal and CLI outputs attached. [ELEVATED]
   Expected result: Escalation created with rollback evidence.

## Preventive
Implement these specific controls:

1. Mandatory password-reset checklist in ITSM: Owner = service desk lead; Timing = during deployment; Mode = manual (automation path: mandatory ITSM fields) [REQUIRES: ITSM mandatory-field workflow]. Pass = ticket cannot close until 4 checkboxes (Credential Manager, tasks, services, mapped drives) are checked and one evidence link is attached; Fail = any unchecked box or missing evidence. On fail, closure is blocked and ticket auto-routes to DWP engineer.
2. SIEM multi-source replay alert: Owner = DWP engineer; Timing = during deployment; Mode = automated [REQUIRES: SIEM rule deployment]. Pass = alert fires when same user has Event 4771 or 4776 from >=2 distinct SourceAddress/Workstation values within 5 minutes; Fail = known test replay does not trigger. On fail, raise P2 to release engineer to fix rule before next rollout.
3. DC scheduled lockout report: Owner = DWP engineer; Timing = after deployment; Mode = automated [REQUIRES: scheduled query job + DWP queue integration]. Pass = report every 15 minutes with Event IDs 4740 and 4771 grouped by AccountName, Workstation, SourceAddress, and count; Fail = no report in 20 minutes or missing fields. On fail, open infra ticket and switch to manual `Get-WinEvent` check every 15 minutes.
4. Block personal accounts in automation contexts: Owner = image owner; Timing = before deployment; Mode = automated. Pass = policy audit shows 0 scheduled tasks and 0 services with StartName matching `FINBRIDGE\\<user>` on released image; Fail = count > 0. On fail, change manager rejects release and requires conversion to managed service accounts.
5. Unlock evidence gate in runbook: Owner = service desk lead; Timing = during deployment; Mode = manual (automation path: workflow rule) [REQUIRES: unlock approval workflow]. Pass = unlock step is unavailable until ticket includes source host/IP evidence and screenshot/text of Event 4740 + 4771 correlation; Fail = unlock performed without evidence. On fail, create process-breach review and retrain queue within 2 business days.
6. Pre-deployment smoke-test gate: Owner = release engineer; Timing = before deployment; Mode = manual (automation path: pipeline gate) [REQUIRES: release pipeline quality gate]. Pass = test account completes sign-in and shows zero new 4625/4771/4776/4740 events for 15 minutes on pilot host; Fail = any listed event appears. On fail, stop deployment and keep current image.
7. In-flight rollout monitoring window: Owner = DWP engineer; Timing = during deployment; Mode = automated [REQUIRES: AVD + SIEM dashboard]. Pass = during first 60 minutes, lockout alerts remain below threshold (<=1 user with 4740 per 15-minute bucket); Fail = threshold exceeded. On fail, trigger rollback and set affected host to drain mode immediately.
8. Post-deployment health validation: Owner = change manager; Timing = after deployment; Mode = manual. Pass = two checks completed before change closure: `az desktopvirtualization session-host show` returns `status=Available` and `allowNewSession=true` for all POOL-FIN-01 hosts, and Security log shows no new 4740 for 30 minutes; Fail = any host unhealthy or any new 4740. On fail, keep change open and assign DWP engineer for remediation.
9. Rollback trigger threshold: Owner = change manager; Timing = during deployment; Mode = manual with automated signal [REQUIRES: alert-to-ITSM integration]. Pass = rollback is initiated when trigger met: >=3 unique users hit Event 4740 in 15 minutes on POOL-FIN-01 or one host shows repeated Event 1000 + 9009 pair 3 times in 10 minutes; Fail = threshold met but no rollback. On fail, auto-page release engineer and incident manager.
10. Knowledge and asset update control: Owner = DWP engineer; Timing = after deployment; Mode = manual. Pass = within 2 business days, update runbook, L1 KB, and L2/L3 KB with incident deltas and add one completed tabletop review record; Fail = updates missing after SLA. On fail, change manager blocks next related change window until documentation is completed.

## Related
- RCA-cthompson-login-lockout-resolution-20260806.md
- known-error-cthompson-login-lockout-20260806.md
- cthompson-login-failure-ranked-hypotheses-20260806.md
- cthompson-incident-communications-20260806.md
- cthompson-login-closure-note-20260806.md
- RUNBOOK-cthompson-login-lockout-replay-containment-20260807.md
- KB-L1-account-sign-in-locked-self-service.md