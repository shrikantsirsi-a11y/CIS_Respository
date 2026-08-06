# Root Cause Analysis (RCA): AVD Black Screen / Session Disconnect - POOL-FIN-01

## 1) Executive Summary
A login-impacting incident affected users in AVD host pool POOL-FIN-01, presenting as a black screen after successful credential entry and, in many cases, immediate session disconnect. The condition was isolated to POOL-FIN-01 after an overnight image update and was not observed in POOL-FIN-02.

The recommended resolution was implemented, and service was restored at 10:00 AM local time. Post-remediation validation confirmed users were able to log in to POOL-FIN-01 hosts successfully, and no further issues were reported.

## 2) Incident Details
| Field | Value |
|---|---|
| Incident Type | Service degradation (AVD login experience) |
| Affected Service | Azure Virtual Desktop |
| Affected Pool | POOL-FIN-01 |
| Unaffected Control Pool | POOL-FIN-02 |
| First User Reports | ~07:00 AM |
| Resolution Time | 10:00 AM |
| User Impact | Approx. 40% of POOL-FIN-01 users experienced black screen or disconnect post-login |
| Severity | SEV-2 (major degradation, partial outage in business-critical pool) |

## 3) Business Impact
- Finance users were blocked or delayed at start of business operations.
- Session reliability was inconsistent, causing repeated reconnect attempts.
- Service desk load increased due to user troubleshooting and reassignment requests.

## 4) Supporting Evidence

### A) Change Correlation Evidence
- POOL-FIN-01 received an overnight image update at 02:00.
- POOL-FIN-02 did not receive the same update and remained healthy.
- Symptom onset followed the update window and was confined to the updated pool.

### B) Host-Level Failure Signature (Affected Host Example: SHFIN-01-A)
Observed pattern during failed user sessions:
- `Event 21` (TerminalServices-LocalSessionManager): session logon succeeded.
- `Event 1000` (Application Error): `dwm.exe` faulting module `igdumd64.dll`, exception `0xc0000005`.
- `Event 9009` (Desktop Window Manager): DWM exited with error.
- `Event 40` (TerminalServices-LocalSessionManager): session disconnected.

This sequence repeated across multiple login attempts and users on affected hosts.

### C) Control Evidence (Healthy Host Example: SHFIN-02-A / POOL-FIN-02)
- `Event 21`: session logon succeeded.
- `Event 9011`: DWM started successfully.
- No corresponding `Event 1000` for `dwm.exe` in the same observation window.

### D) Resolution Validation Evidence
After applying the recommended remediation:
- Affected hosts stopped producing new `Event 1000` (`dwm.exe` / `igdumd64.dll`) during validation logons.
- No immediate post-logon disconnect chain (`Event 21` -> `Event 40`) observed in validation window.
- User verification completed at 10:00 AM: users successfully logging into hosts in POOL-FIN-01.
- No new user incidents reported after restoration checkpoint.

## 5) Detailed Timeline (Local Time)
| Time | Event | Evidence / Observation |
|---|---|---|
| 02:00 AM | Image update deployed to POOL-FIN-01 | Change window for updated pool |
| ~07:00 AM | First user reports begin | Black screen after login in POOL-FIN-01 |
| 07:02-07:09 AM | Repeated host failures observed | `Event 21` -> `Event 1000` (`dwm.exe`/`igdumd64.dll`) -> `Event 9009` -> `Event 40` |
| 07:15-08:00 AM | Scope confirmed | Approx. 40% impact in POOL-FIN-01; POOL-FIN-02 unaffected |
| 08:00-09:00 AM | Containment and mitigation actions | Affected hosts drained; users redirected where possible |
| 09:00-09:45 AM | Corrective action applied | Recommended resolution executed on affected pool/hosts |
| 09:45-10:00 AM | Validation cycle | Test logons successful; no recurrence indicators |
| 10:00 AM | Incident resolved | Users verified logging in to POOL-FIN-01 with no issues reported |

## 6) Root Cause Statement
The incident was caused by a graphics-stack regression introduced through the overnight POOL-FIN-01 image update. During user sign-in, `dwm.exe` crashed in `igdumd64.dll`, causing desktop initialization failure (black screen) and frequent session disconnects. The issue was limited to the updated pool, while the non-updated control pool remained stable.

## 7) 5-Why Analysis
1. Why did users see a black screen and session instability after login?
Because desktop initialization failed or terminated right after authentication, causing disconnected or unusable sessions.

2. Why did desktop initialization fail?
Because DWM (`dwm.exe`) repeatedly crashed during post-login rendering.

3. Why was DWM crashing?
Because `dwm.exe` faulted in Intel graphics module `igdumd64.dll` (`Event 1000`, exception `0xc0000005`) on affected hosts.

4. Why was the faulty graphics path present on affected hosts?
Because the overnight image update introduced a graphics driver/stack state that was not stable in POOL-FIN-01 production login conditions.

5. Why was this not prevented before broad deployment?
Because deployment controls did not enforce a sufficiently strict canary and post-deploy health gate for graphics-stack regressions (for example, DWM crash spike detection before full user traffic exposure).

## 8) Corrective Actions Taken
- Isolated impact by draining problematic hosts and reducing new session placement on affected nodes.
- Executed recommended remediation path on POOL-FIN-01 (image/host correction).
- Performed controlled validation logons before re-opening pool capacity.
- Confirmed service restoration with user verification at 10:00 AM.

## 9) Preventive Actions (CAPA)
| Preventive Action | Owner | Priority | Target |
|---|---|---|---|
| Enforce canary rollout for image changes (small host subset before full pool) | EUC Platform Team | High | Immediate |
| Add release gate for graphics driver/stack deltas in image pipeline | Image Engineering | High | 2 weeks |
| Implement automated alerting on `Event 1000` (`dwm.exe`) and post-logon disconnect spikes | Monitoring/Operations | High | 2 weeks |
| Define rollback trigger thresholds (for example, login failure/disconnect rate) and automate rollback decision workflow | Operations Engineering | Medium | 3 weeks |
| Add pre-production synthetic login tests for AVD image promotion | QA / Platform Validation | Medium | 3 weeks |
| Update incident runbook with explicit evidence checklist and triage sequence | Service Desk + EUC | Medium | 1 week |

## 10) Lessons Learned
- A control pool is highly effective for rapid elimination of tenant-wide hypotheses.
- DWM crash telemetry is a critical leading indicator for black-screen incidents.
- Canary + automated health gates must be mandatory for image changes, especially graphics and agent layers.

## 11) Closure Criteria and Status
- Service restoration confirmed: Yes (10:00 AM).
- User validation confirmed: Yes (users logging in to POOL-FIN-01 successfully).
- Monitoring stabilized with no fresh incident reports in post-resolution watch window: Yes.
- RCA completed with corrective and preventive actions: Yes.

## 12) Final Conclusion
This was an image-induced, pool-scoped technical regression, not a user behavior issue and not a tenant-wide AVD outage. Applying the recommended remediation restored service by 10:00 AM. The preventive plan focuses on stronger image release controls, earlier crash detection, and faster rollback pathways to reduce recurrence risk and restore time in future incidents.
