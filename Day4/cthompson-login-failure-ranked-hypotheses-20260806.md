# cthompson Login Failure - Ranked Hypotheses (2026-08-06)

## Scope Facts
- Symptom: user cthompson not able to login
- Who: cthompson only one user
- Since: ~08:40 this morning
- Change: Nil

## Ranked Top 5 Likely Causes

### 1) AD account lockout (or bad-password lockout loop)
Why this fits the scope facts:
- Only one user is affected.
- The issue started at a specific time (~08:40).
- No broader service or platform change is reported.
- This pattern commonly matches repeated bad-password attempts from one device/app causing lockout.

Single fastest check:
- In AD/Azure sign-in logs, check whether cthompson shows account lockout or repeated bad-password failures starting around 08:40.

### 2) Password expired or recently changed but not updated everywhere
Why this fits the scope facts:
- Single-user impact and abrupt start are consistent with password expiry boundary conditions.
- Stale saved credentials on one endpoint/app can begin failing suddenly.

Single fastest check:
- Verify password status (pwdLastSet/expiry), then test a password reset and immediate clean sign-in.

### 3) MFA or conditional access challenge failure for this user
Why this fits the scope facts:
- User-specific MFA device issues or conditional access condition mismatches can affect one person only.
- No estate-wide change does not rule out user-context policy enforcement.

Single fastest check:
- Review the latest Entra ID sign-in event for cthompson and read the exact failure reason (for example MFA denied or CA policy blocked).

### 4) Account state issue (disabled, expired, restricted logon hours/workstation)
Why this fits the scope facts:
- A user-only symptom can be caused by account state or restriction flags taking effect at a specific time.

Single fastest check:
- Open the user object and verify enabled status, account expiry, logon-hours, and workstation restrictions in one pass.

### 5) Endpoint/session-specific issue (cached creds/profile/token corruption)
Why this fits the scope facts:
- One affected user with no known environment change can still indicate local credential cache/profile/session corruption.

Single fastest check:
- Attempt login for cthompson on a known-good alternate device/session. If successful, isolate to endpoint/profile/session.

## Note
- This is a ranked hypothesis list only. No single root cause is confirmed at this stage.

## Addendum - Evidence Review and Elimination (2026-08-06)

### Incident Evidence (Security Event Log - DESKTOP-FB022, 2024-03-15 08:44-09:12)
- 08:44:01 Event 4776 Audit Failure: credentials validation failed, error 0xC000006A (wrong password), account FINBRIDGE\cthompson, source workstation DESKTOP-FB022.
- 08:44:03 Event 4625 Audit Failure: unknown user name or bad password, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:28 Event 4625 Audit Failure: unknown user name or bad password, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:55 Event 4625 Audit Failure: unknown user name or bad password, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:56 Event 4740 Audit Failure: user account locked out, account FINBRIDGE\cthompson, caller computer DESKTOP-FB022.
- 08:45:10 Event 4625 Audit Failure: account locked out, logon type 7 (unlock attempt), source DESKTOP-FB022.
- 08:45:44 Event 4771 Audit Failure: Kerberos pre-authentication failed, failure code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:01 Event 4771 Audit Failure: Kerberos pre-authentication failed, failure code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:33 Event 4771 Audit Failure: Kerberos pre-authentication failed, failure code 0x18 (wrong password), source IP 10.10.8.112.

### Hypothesis-by-Hypothesis Evidence Judgement

#### 1) AD account lockout (or bad-password lockout loop)
Judgement: Supports.
Evidence basis:
- 4776 at 08:44:01 shows wrong password (0xC000006A).
- Repeated 4625 at 08:44:03, 08:44:28, 08:44:55 show bad password attempts.
- 4740 at 08:44:56 confirms lockout.
- 4625 at 08:45:10 confirms subsequent account-locked-out failure.

#### 2) Password expired or recently changed but not updated everywhere
Judgement: Supports (weak to moderate).
Evidence basis:
- 4776 at 08:44:01 and 4771 at 08:45:44, 08:46:01, 08:46:33 indicate wrong-password conditions.
- Pattern is compatible with stale saved credentials, but no explicit password-expiry event is present.

#### 3) MFA or conditional access challenge failure for this user
Judgement: Contradicts.
Evidence basis:
- 4776 at 08:44:01 and 4771 at 08:45:44, 08:46:01, 08:46:33 are direct credential failures (wrong password).
- 4740 at 08:44:56 confirms lockout sequence from bad-password attempts.
- No MFA/CA-specific denial events are present in the provided evidence.

#### 4) Account state issue (disabled, expired, restricted logon hours/workstation)
Judgement: Contradicts.
Evidence basis:
- 4776 at 08:44:01 points to wrong password rather than disabled/expired/restriction state.
- 4740 at 08:44:56 and 4625 at 08:45:10 explain failure as lockout-driven.

#### 5) Endpoint/session-specific issue (cached creds/profile/token corruption)
Judgement: Supports.
Evidence basis:
- DESKTOP-FB022 generated repeated interactive failures (4625 at 08:44:03, 08:44:28, 08:44:55).
- Separate source 10.10.8.112 generated repeated Kerberos wrong-password failures (4771 at 08:45:44, 08:46:01, 08:46:33).
- Multi-source replay behavior aligns with cached/stored credential loops.

### Surviving Hypothesis After Elimination
- Account lockout caused by repeated bad-password submissions (credential replay loop), most likely from stale saved credentials on one or more sources.

### Detailed Resolution Steps

#### 1) Contain the lockout loop
- Isolate both known sources from further auth attempts:
- DESKTOP-FB022.
- Source at 10.10.8.112.
- Practical containment: sign out sessions, temporarily disconnect from network, or stop tasks/services authenticating as cthompson.

#### 2) Restore account access safely
- Unlock cthompson in AD.
- Reset password to a temporary strong value.
- Confirm one successful sign-in on a clean endpoint.

#### 3) Remove stale credentials on DESKTOP-FB022
- Clear Credential Manager entries (Windows and Generic Credentials) for domain, VPN, Outlook, mapped drives, and legacy targets.
- Remove persisted mapped drive credentials.
- Remove stale Office/Outlook cached auth artifacts.
- Check and correct scheduled tasks or services running as cthompson.
- Reboot DESKTOP-FB022 after cleanup.

#### 4) Investigate and clean 10.10.8.112
- Identify the asset/workload owner.
- Check scheduled tasks, services, scripts, RDP saved credentials, and VPN/auth caches using cthompson.
- Remove/update stale credentials.
- Restart affected services/tasks only after correction.

#### 5) Re-issue final password
- Reset to final user-known password after all sources are cleaned.
- Enforce change-at-next-logon if policy applies.
- Validate login and primary app access.

#### 6) Verify stabilization
- Monitor for 30-60 minutes:
- No new 4776 wrong-password events for cthompson.
- No new 4771 (0x18) events for cthompson.
- No new 4740 lockout events.
- If failures continue, identify new source and repeat source-cleanup steps.

#### 7) Prevent recurrence
- Remove personal user accounts from automation contexts.
- Migrate scheduled/service authentication to managed service accounts where appropriate.
- Record offending source(s), cleaned artifacts, and verification results in the incident record.