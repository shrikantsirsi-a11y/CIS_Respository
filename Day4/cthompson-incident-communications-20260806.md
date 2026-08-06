# cthompson Incident Communications (Three Audiences)

## Audience 1 - Non-technical Executive
Your access and data are safe. This morning, only one account (cthompson) was affected when repeated incorrect sign-in attempts from two devices temporarily blocked access. There was no wider system change. IT stopped the repeated attempts, restored the account at 09:08, and verified successful sign-in at 09:09 with no further issues reported. No action is required from you.

## Audience 2 - Affected End-User Team (Non-technical)
Hi team, from about 08:40 this morning, one account (cthompson) could not sign in because repeated incorrect password attempts from two devices temporarily blocked that account, and this was not caused by a wider system change. IT stopped the repeated attempts, restored the account at 09:08, and verified successful sign-in at 09:09 with no further issues reported. If you see the same issue, contact the IT Service Desk immediately and share your device name and the time it happened. Contact: IT Service Desk.

## Audience 3 - Engineer-to-Engineer Internal Note
Incident: Single-user auth failure for FINBRIDGE\\cthompson, start ~08:40, resolved 09:09.

Root cause:
- AD account lockout after repeated bad-password submissions (multi-source credential replay pattern).

Supporting evidence:
- 08:44:01 Event 4776, 0xC000006A wrong password, source workstation DESKTOP-FB022.
- 08:44:03 / 08:44:28 / 08:44:55 Event 4625, Logon Type 2, bad password, source DESKTOP-FB022.
- 08:44:56 Event 4740, account FINBRIDGE\\cthompson locked out, caller DESKTOP-FB022.
- 08:45:10 Event 4625, Logon Type 7, account locked out.
- 08:45:44 / 08:46:01 / 08:46:33 Event 4771, failure code 0x18 wrong password, source IP 10.10.8.112.
- No evidence of broad platform/policy change during the window.

Exact actions taken:
- Contained repeated authentication attempts from DESKTOP-FB022 and source IP 10.10.8.112.
- Restored account state: Event 4722 at 09:08:14 (account FINBRIDGE\\cthompson enabled by FINBRIDGE\\helpdesk-admin).
- Cleared/updated stored credential paths implicated in replay behavior.
- Validated clean auth path post-fix.

Config/technical detail captured:
- Account: FINBRIDGE\\cthompson.
- Primary host: DESKTOP-FB022.
- Secondary auth source: 10.10.8.112.
- Event set used for triage/closure: 4776, 4625, 4740, 4771, 4722, 4624.

Verification step and closure evidence:
- Event 4624 at 09:09:01, Logon Type 2 interactive success for FINBRIDGE\\cthompson from DESKTOP-FB022.
- User verified successful login and no further issues reported at 09:09.

Preventive action required:
- Identify owner/workload for 10.10.8.112 and remove stale credentials tied to cthompson.
- Run source-focused monitoring for repeat 4771/4776 signals.
- Enforce reset-time credential cleanup checklist (Credential Manager, mapped drives, tasks, services, app token stores).
- Keep lockout triage runbook requiring host/IP source pivot before unlock.
- Migrate automation away from personal user creds to managed service accounts where applicable.
