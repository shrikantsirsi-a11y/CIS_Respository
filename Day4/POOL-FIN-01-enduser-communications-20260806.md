# End-User Communications: POOL-FIN-01 Incident (2026-08-06)

## Audience 1 - Non-technical executive
Your access is restored, and there is no indication of data impact. Around 7:00 AM, about 40% of Finance users in POOL-FIN-01 saw a black screen or disconnect after sign-in; POOL-FIN-02 was unaffected. The issue followed a 2:00 AM image update and was resolved by 10:00 AM after isolating affected systems, redirecting users, applying the correction, and validating successful logins. No action is needed unless it happens again; if it does, contact the Service Desk.

## Audience 2 - Affected end-user team
Hi team, your access is restored and there is no indication of data impact. Starting around 7:00 AM, about 40% of users in Finance desktop group POOL-FIN-01 saw a black screen or were disconnected after sign-in because last night’s 2:00 AM desktop image update caused a display startup failure on that group only (POOL-FIN-02 stayed normal). We fixed this by isolating affected systems, redirecting users, applying the correction, and validating logins; service was fully restored at 10:00 AM with no new issues reported. If you see this again, reconnect once, then contact the Service Desk.

## Audience 3 - Engineer-to-engineer internal note
Incident: POOL-FIN-01 login degradation (SEV-2), first reports ~07:00, resolved 10:00 local.

Impact:
- Approx. 40% of POOL-FIN-01 users hit black screen post-auth and/or immediate disconnect.
- POOL-FIN-02 unaffected (control pool).

Root cause:
- Graphics-stack regression introduced by 02:00 image update to POOL-FIN-01.
- Failure chain on affected hosts: Event 21 (logon success) -> Event 1000 (dwm.exe faulting igdumd64.dll, 0xc0000005) -> Event 9009 (DWM exit) -> Event 40 (session disconnect).
- Control hosts showed Event 21 + Event 9011 (DWM start) without matching Event 1000 signature.

Exact actions taken:
- Drained problematic POOL-FIN-01 hosts to stop new-session placement.
- Redirected impacted users to available healthy capacity.
- Executed recommended remediation on POOL-FIN-01 (image/host correction path).
- Ran controlled validation logons before reopening pool capacity.

Config/detail captured:
- Change correlation: POOL-FIN-01 updated at 02:00; POOL-FIN-02 not updated.
- Host examples used in analysis: affected SHFIN-01-A, control SHFIN-02-A.
- AVD context: pool-scoped regression, not tenant-wide outage.

Verification:
- No new Event 1000 (dwm.exe/igdumd64.dll) during validation window.
- No immediate Event 21 -> Event 40 post-logon disconnect chain in validation.
- User verification complete at 10:00: successful logins to POOL-FIN-01, no fresh issue reports.

Preventive actions required:
- Enforce mandatory canary rollout for image changes.
- Add release gate for graphics driver/stack deltas.
- Alerting on Event 1000 (dwm.exe) spikes and post-logon disconnect spikes.
- Define rollback trigger thresholds and automate rollback decision workflow.
- Add pre-prod synthetic login tests for image promotion.
- Update runbook with explicit evidence checklist and triage sequence.
