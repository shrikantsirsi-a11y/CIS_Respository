Title: POOL-FIN-01 Black Screen / Post-Login Disconnect Recovery Runbook
Version: 1.0
Date: 07/08/2026
Author: Srikantha Satyanarayan
Reviewed: self
Status: draft
Change: initial version from RCA

# Runbook: POOL-FIN-01 Black Screen / Post-Login Disconnect Recovery

## Scope
Use this runbook when users in POOL-FIN-01 report black screen after credential entry, immediate disconnect, or both, and event telemetry indicates DWM/graphics crash behavior.

## Prerequisites
1. Access: Azure role with rights to manage AVD host pools and session hosts (minimum equivalent: Desktop Virtualization Contributor). [ELEVATED]
2. Access: Rights to read Log Analytics / Azure Monitor logs for AVD hosts. [ELEVATED]
3. Access: Rights to restart VMs and apply image/host remediation in the subscription/resource group that contains POOL-FIN-01. [ELEVATED]
4. Tool: Azure Portal access from a stable admin workstation.
5. Tool: PowerShell 7+ with Az modules installed (`Az.Accounts`, `Az.DesktopVirtualization`, `Az.Compute`).
6. Input: Host pool name (`POOL-FIN-01`) and resource group name.
7. Input: Approved known-good image reference/version used by the healthy control path (the same baseline used by POOL-FIN-02).
8. Input: Incident ticket number for change/audit tracking.

## Procedure
1. Open https://portal.azure.com and sign in with your incident admin account.
Expected result: The Azure Portal home page loads and your account is shown in the top-right profile menu.

2. Navigate to Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts.
Expected result: The Session hosts grid for POOL-FIN-01 is visible.

3. Open your incident ticket in the ITSM console and set status to Mitigation in progress.
Expected result: Ticket status changes to Mitigation in progress and your name is shown as assignee/owner.

4. In the same POOL-FIN-01 blade, open Diagnostic settings and note the Log Analytics workspace name receiving host diagnostics.
Expected result: You have one workspace name recorded in the ticket work notes.

5. Navigate to Azure Monitor -> Logs and select the workspace identified in Step 4.
Expected result: Log Analytics query editor opens with the correct workspace selected.

6. Run this KQL query with Time range set to Last 3 hours:
Expected result: Query returns rows with affected host names.

```kusto
Event
| where TimeGenerated >= ago(3h)
| where EventID == 1000
| where Source == "Application Error"
| where RenderedDescription has "dwm.exe"
| where RenderedDescription has "igdumd64.dll"
| project TimeGenerated, Computer, EventID, RenderedDescription
| order by TimeGenerated desc
```

7. Copy unique values from the Computer column into the ticket as Affected host list.
Expected result: Ticket contains a non-empty host list with one hostname per line.

8. Return to Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts and set Allow new sessions to No for each host in Affected host list. [ELEVATED]
Expected result: Each selected host shows Allow new sessions = No.

9. Open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions and send message "Maintenance in progress. Save work and reconnect in 5 minutes." to sessions on affected hosts.
Expected result: Message action returns success for each targeted session.

10. In the same User sessions blade, sign out all sessions running on affected hosts. [ELEVATED]
Expected result: Active sessions count for each affected host becomes 0 in under 5 minutes.

11. Open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> select one affected host -> Virtual machine.
Expected result: The VM resource page for that session host opens.

12. On the VM page, run the approved image remediation action for that host (Reimage if enabled by your platform standard, otherwise Replace host from approved image pipeline). [ELEVATED]
Expected result: Azure shows the operation as Succeeded in Activity log for that VM.

13. Repeat Step 11 and Step 12 for each remaining host in Affected host list. [ELEVATED]
Expected result: Every affected host has a Succeeded remediation operation in Activity log.

14. Restart each remediated VM from Virtual machine -> Overview -> Restart. [ELEVATED]
Expected result: VM power state returns to Running and status checks show Available.

15. Set Allow new sessions to Yes for exactly one remediated host in POOL-FIN-01 -> Session hosts. [ELEVATED]
Expected result: One host shows Allow new sessions = Yes and all other remediated hosts remain No.

16. Start a test user session through the AVD Remote Desktop client to POOL-FIN-01.
Expected result: Desktop loads in under 60 seconds with no black screen and no disconnect for 5 continuous minutes.

17. Re-run the KQL query from Step 6 with Time range set to Last 15 minutes and add a filter for the canary host name.
Expected result: Zero rows are returned for that canary host.

18. Set Allow new sessions to Yes for the remaining remediated hosts. [ELEVATED]
Expected result: All remediated hosts show Allow new sessions = Yes.

19. Watch Azure Monitor alerts and the service desk queue for 30 minutes.
Expected result: Zero new POOL-FIN-01 black-screen or immediate-disconnect incidents are created during the watch window.

20. Update the ticket with host list, KQL results, remediation operation IDs, test login result, and closure recommendation.
Expected result: Ticket contains complete evidence and is ready for resolver group lead approval to close.

## Verification
1. In Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions, confirm at least 3 different user principals have active sessions on remediated hosts.
Pass condition: 3 or more unique users remain connected for at least 5 minutes each without reconnect loops.

2. In Azure Monitor -> Logs for the same workspace, run the Step 6 KQL query with Time range set to Last 30 minutes.
Pass condition: Query returns zero rows for all remediated hosts.

3. In Azure Monitor -> Logs, run this disconnect-chain KQL query with Time range set to Last 30 minutes:
Pass condition: Query returns zero rows.

```kusto
Event
| where TimeGenerated >= ago(30m)
| where EventID in (21, 40)
| summarize events = make_set(EventID), firstSeen = min(TimeGenerated), lastSeen = max(TimeGenerated) by Computer, bin(TimeGenerated, 2m)
| where set_has_element(events, 21) and set_has_element(events, 40)
| project Computer, firstSeen, lastSeen, events
| order by firstSeen desc
```

4. In the service desk queue filter for Category = AVD and Configuration Item contains POOL-FIN-01 for the last 30 minutes.
Pass condition: Zero new incidents with symptoms black screen, disconnect after login, or reconnect loop.

## Rollback
Use this rollback immediately if failures reappear after reopening any remediated host.
Target completion time for Steps 1-6: under 3 minutes.

1. Open https://portal.azure.com -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts.
Expected result: Session hosts grid is visible.

2. Filter Session hosts by Name contains `SHFIN-01` or by the affected host list from the ticket, then select all remediated hosts from this change window.
Expected result: Only recently changed hosts are selected.

3. Click More -> Set drain mode -> Allow new sessions = No for the selected hosts. [ELEVATED]
Expected result: Each selected host shows Allow new sessions = No within 30 seconds.

4. Go to Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions, filter Host pool = POOL-FIN-01 and Session state = Active, then Send message: "Emergency rollback in progress. Reconnect now."
Expected result: Message action returns success for active sessions.

5. In the same User sessions blade, select sessions on remediated hosts and click Sign out. [ELEVATED]
Expected result: Active sessions on remediated hosts drop to 0 within 2 minutes.

6. Open Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts and confirm at least one host shows Allow new sessions = Yes.
Expected result: POOL-FIN-02 is open for user reconnection.

7. Open the incident ticket and post this exact update: "Rollback executed: POOL-FIN-01 remediated hosts drained and sessions signed out; users redirected to POOL-FIN-02 at <time>."
Expected result: Ticket timeline contains timestamped rollback evidence.

8. If POOL-FIN-02 has no capacity, open Teams/bridge and page EUC Platform On-Call + Image Engineering immediately as Major Incident. [ELEVATED]
Expected result: Escalation acknowledged by both teams.

9. After service is stable, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts and reimage drained hosts back to the last known-good image baseline used before the 02:00 update. [ELEVATED]
Expected result: Each host shows remediation Activity log status = Succeeded.

10. Keep reimaged hosts drained until one-host canary validation passes (successful login plus zero DWM crash hits in 15 minutes), then reopen one host at a time. [ELEVATED]
Expected result: POOL-FIN-01 capacity returns gradually without recurrence.

## Notes
- This incident pattern is pool-scoped and image-linked; use POOL-FIN-02 as control evidence when confirming blast radius.
- The key failure signature is `dwm.exe` faulting in `igdumd64.dll` (often with exception `0xc0000005`) followed by DWM exit and session disconnect.
- Do not reopen all hosts at once after remediation; reopen with canary-first sequence to avoid broad recurrence.
- Capture and attach KQL query output and affected host list to the ticket before closure.
- Related records: Day4 incident and RCA set for POOL-FIN-01 black-screen event dated 2026-08-06.
