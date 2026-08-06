# RCA - cthompson Login Failure and Account Lockout

Date: 2026-08-06
Incident window: 08:40 to 09:09 (local time)
Status: Resolved

## 1) Executive Summary
At approximately 08:40, user FINBRIDGE\\cthompson was unable to log in. Security logs show repeated wrong-password attempts from DESKTOP-FB022, followed by account lockout. Additional wrong-password Kerberos pre-authentication attempts continued from source IP 10.10.8.112, indicating a credential replay pattern from more than one source. Resolution actions focused on containing credential replay, restoring account state, and validating clean authentication. Service was restored at 09:09 with verified successful interactive logon and no further user-reported issues.

## 2) Scope and Impact
- Affected user: FINBRIDGE\\cthompson
- Affected population: Single user only
- Symptom: User unable to log in
- Start time: About 08:40
- Change correlation: No known platform or policy change
- Business impact: User work interruption until access was restored

## 3) Supporting Evidence

### Initial failure and lockout sequence
- 08:44:01 - Security Event 4776 (Audit Failure)
  - Domain controller attempted credential validation
  - Account: FINBRIDGE\\cthompson
  - Error: 0xC000006A (wrong password)
  - Source workstation: DESKTOP-FB022

- 08:44:03 - Security Event 4625 (Audit Failure)
  - Failure reason: Unknown user name or bad password
  - Logon type: 2 (Interactive)
  - Source: DESKTOP-FB022

- 08:44:28 - Security Event 4625 (Audit Failure)
  - Failure reason: Unknown user name or bad password
  - Logon type: 2 (Interactive)
  - Source: DESKTOP-FB022

- 08:44:55 - Security Event 4625 (Audit Failure)
  - Failure reason: Unknown user name or bad password
  - Logon type: 2 (Interactive)
  - Source: DESKTOP-FB022

- 08:44:56 - Security Event 4740 (Audit Failure)
  - Account locked out
  - Account: FINBRIDGE\\cthompson
  - Caller computer: DESKTOP-FB022

- 08:45:10 - Security Event 4625 (Audit Failure)
  - Failure reason: Account locked out
  - Logon type: 7 (Unlock attempt)
  - Source: DESKTOP-FB022

### Continued wrong-password attempts from second source
- 08:45:44 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed
  - Failure code: 0x18 (wrong password)
  - Source IP: 10.10.8.112

- 08:46:01 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed
  - Failure code: 0x18 (wrong password)
  - Source IP: 10.10.8.112

- 08:46:33 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed
  - Failure code: 0x18 (wrong password)
  - Source IP: 10.10.8.112

### Recovery verification evidence
- 09:08:14 - Security Event 4722 (Audit Success)
  - A user account was enabled
  - Account: FINBRIDGE\\cthompson
  - Done by: FINBRIDGE\\helpdesk-admin

- 09:09:01 - Security Event 4624 (Audit Success)
  - Successful account logon
  - Account: FINBRIDGE\\cthompson
  - Logon type: 2 (Interactive)
  - Source: DESKTOP-FB022

- 09:09 - User verified login success and no further issues reported

## 4) Detailed Timeline
- 08:40 (approx) - User reports inability to log in.
- 08:44:01 - First recorded wrong-password validation failure (Event 4776).
- 08:44:03 to 08:44:55 - Repeated interactive bad-password attempts from DESKTOP-FB022 (Event 4625 x3).
- 08:44:56 - Account lockout triggered (Event 4740).
- 08:45:10 - Unlock-attempt logon fails because account is locked (Event 4625).
- 08:45:44 to 08:46:33 - Continued wrong-password Kerberos pre-auth failures from 10.10.8.112 (Event 4771 x3).
- 09:08:14 - Account enabled by helpdesk-admin (Event 4722).
- 09:09:01 - Successful interactive logon from DESKTOP-FB022 (Event 4624).
- 09:09 - Incident marked resolved after user confirmation.

## 5) Root Cause Statement
Primary root cause:
- Account lockout caused by repeated bad-password submissions for FINBRIDGE\\cthompson.

Contributing causes:
- Repeated interactive bad-password attempts from DESKTOP-FB022.
- Additional wrong-password pre-authentication attempts from separate source IP 10.10.8.112, consistent with stale cached credentials or automated retry behavior.

What this was not:
- No supporting evidence for MFA or conditional access denial in provided logs.
- No supporting evidence for disabled/expired/restricted account as initiating cause.

## 6) Five Whys Analysis
1. Why could the user not log in?
- Because the account was locked out (Event 4740 at 08:44:56), causing subsequent login attempts to fail.

2. Why was the account locked out?
- Because multiple bad-password attempts were submitted in a short period (Events 4776 and 4625 between 08:44:01 and 08:44:55).

3. Why were multiple bad-password attempts submitted?
- Because one or more sources were using invalid/stale credentials (DESKTOP-FB022 and source IP 10.10.8.112 evidenced by Events 4625 and 4771).

4. Why were stale credentials still being used?
- Cached or stored credentials (interactive session, service, scheduled task, mapped drive, or application token cache) likely continued replaying old authentication data.

5. Why did this stale-credential condition result in lockout before detection?
- Existing controls did not prevent or quickly isolate multi-source credential replay for a user account before lockout threshold was reached.

Systemic root cause:
- Credential hygiene and replay-source control were insufficient to prevent stale credential retries from triggering AD lockout.

## 7) Resolution Actions Performed
- Contained credential replay sources.
- Restored account state (re-enabled account) by authorized helpdesk admin.
- Cleared/updated credential paths and validated authentication path.
- Confirmed successful interactive login at 09:09:01 (Event 4624).
- Confirmed end-user service restoration with no immediate recurrence reported.

## 8) Preventive and Corrective Actions

### Immediate preventive actions (0-2 days)
- Identify owner and function of source IP 10.10.8.112; remove any stored stale credentials tied to cthompson.
- Review DESKTOP-FB022 for stored credentials in Credential Manager, mapped drives, scheduled tasks, and services.
- Run targeted lockout-source monitoring for cthompson for 24 hours.

### Short-term hardening (this week)
- Enforce standard cleanup checklist during password resets: cached creds, tasks, services, drive mappings, and app token stores.
- Implement lockout triage runbook requiring source host/IP pivot before unlock.
- Add analyst checklist to capture Event IDs 4776, 4625, 4740, 4771, and post-fix 4624/4722 evidence.

### Medium-term prevention (2-4 weeks)
- Eliminate use of personal user accounts in automation contexts; migrate to managed service accounts where applicable.
- Add detections for multi-source wrong-password bursts for a single user.
- Review account lockout threshold and alerting sensitivity to balance security with operational resilience.

## 9) Validation and Closure Criteria
Closure criteria met:
- Account state restored (Event 4722 at 09:08:14).
- Successful interactive logon confirmed (Event 4624 at 09:09:01).
- User confirmed normal access and no active issue.

Recommended post-closure verification:
- Continue monitoring for repeated 4771/4776 failures for this user over next business day.
- If recurrence occurs, isolate new source and repeat stale-credential eradication workflow.

## 10) Lessons Learned
- Early identification of all authentication sources is critical in single-user lockout incidents.
- A successful unlock alone is insufficient unless replay sources are removed.
- Including both failure and recovery event IDs in closure evidence improves audit quality and incident confidence.
