# Runbook - Resolve Single-User AD Lockout from Multi-Source Credential Replay

Runbook ID: RB-AD-LOCKOUT-CTHOMPSON-20260807
Based on RCA: RCA-cthompson-login-lockout-resolution-20260806.md
Last updated: 2026-08-07
Scope: Single-user lockout where failures originate from workstation DESKTOP-FB022 and secondary source IP 10.10.8.112

---

## Prerequisites

1. Confirm you can sign in to a domain-joined admin workstation.
2. Confirm Active Directory Users and Computers is installed.
3. Confirm Event Viewer is available.
4. Confirm your account can read Domain Controller Security logs. [ELEVATED]
5. Confirm your account can enable and unlock user accounts in Active Directory. [ELEVATED]
6. Confirm your account can reset user passwords in Active Directory. [ELEVATED]
7. Confirm your account can remotely administer DESKTOP-FB022. [ELEVATED]
8. Confirm your account can query DHCP or IPAM records for IP 10.10.8.112. [ELEVATED]
9. Confirm the affected username is FINBRIDGE\\cthompson.
10. Confirm the user can receive a temporary password securely.

---

## Procedure

1. Open Event Viewer on a Domain Controller. [ELEVATED]
   Expected result: Event Viewer opens with access to the Security log.

2. Open Windows Logs > Security. [ELEVATED]
   Expected result: Security events are visible.

3. Apply a Security log filter for Event IDs 4776, 4625, 4740, and 4771. [ELEVATED]
   Expected result: Only authentication-failure and lockout events are shown.

4. Search filtered events for FINBRIDGE\\cthompson. [ELEVATED]
   Expected result: Matching events for the affected account are displayed.

5. Record the caller computer from Event ID 4740. [ELEVATED]
   Expected result: Caller computer is identified as DESKTOP-FB022.

6. Record the source IP from Event ID 4771. [ELEVATED]
   Expected result: Source IP is identified as 10.10.8.112.

7. Open Active Directory Users and Computers. [ELEVATED]
   Expected result: ADUC console opens.

8. Open the FINBRIDGE\\cthompson user object. [ELEVATED]
   Expected result: User properties window opens.

9. Select Disable Account for FINBRIDGE\\cthompson. [ELEVATED]
   Expected result: The account status changes to disabled.

10. Open DHCP or IPAM management console. [ELEVATED]
    Expected result: Lease or address records are accessible.

11. Query IP address 10.10.8.112. [ELEVATED]
    Expected result: Hostname and owner for 10.10.8.112 are identified.

12. Start a remote session to DESKTOP-FB022. [ELEVATED]
    Expected result: Administrative session opens on DESKTOP-FB022.

13. Open Credential Manager on DESKTOP-FB022. [ELEVATED]
    Expected result: Stored Windows credentials are listed.

14. Remove each Windows credential that uses FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: No stored credentials remain for FINBRIDGE\\cthompson.

15. Open Task Scheduler on DESKTOP-FB022. [ELEVATED]
    Expected result: Scheduled tasks inventory is visible.

16. Export the list of tasks configured to Run as FINBRIDGE\\cthompson to a text file at C:\\Temp\\cthompson_tasks_before.txt. [ELEVATED]
    Expected result: Baseline task list file is created.

17. Disable each scheduled task configured to Run as FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: All targeted tasks show Status = Disabled.

18. Open Services on DESKTOP-FB022. [ELEVATED]
    Expected result: Services console opens.

19. Export the list of services that log on as FINBRIDGE\\cthompson to a text file at C:\\Temp\\cthompson_services_before.txt. [ELEVATED]
    Expected result: Baseline service list file is created.

20. Stop each service that logs on as FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: All targeted services show Status = Stopped.

21. Start a remote session to the host identified for 10.10.8.112. [ELEVATED]
    Expected result: Administrative session opens on the second source host.

22. Open Credential Manager on the 10.10.8.112 host. [ELEVATED]
    Expected result: Stored Windows credentials are listed.

23. Remove each Windows credential that uses FINBRIDGE\\cthompson on the 10.10.8.112 host. [ELEVATED]
    Expected result: No stored credentials remain for FINBRIDGE\\cthompson on that host.

24. Open Active Directory Users and Computers. [ELEVATED]
    Expected result: ADUC console is in focus.

25. Reset password for FINBRIDGE\\cthompson to a temporary strong password. [ELEVATED]
    Expected result: Password reset completes successfully.

26. Select User must change password at next logon for FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: Flag is enabled.

27. Enable the FINBRIDGE\\cthompson account. [ELEVATED]
    Expected result: Account status changes to enabled.

28. Unlock the FINBRIDGE\\cthompson account in ADUC. [ELEVATED]
    Expected result: Lockout status clears.

29. Provide the temporary password to the user through an approved secure channel.
   Expected result: User confirms receipt of the temporary password.

30. Instruct the user to sign in on DESKTOP-FB022.
    Expected result: User reaches the password-change prompt or desktop session.

31. Instruct the user to set a new password at first logon.
    Expected result: Password change completes and the desktop loads.

---

## Verification

1. Open Event Viewer on a Domain Controller. [ELEVATED]
   Expected result: Security log is accessible.

2. Filter Security log for Event ID 4624 for FINBRIDGE\\cthompson in the last 15 minutes. [ELEVATED]
   Expected result: At least one successful interactive logon event is present.

3. Filter Security log for Event IDs 4771, 4776, 4625, and 4740 for FINBRIDGE\\cthompson in the last 15 minutes. [ELEVATED]
   Expected result: No new failure or lockout events are present after remediation.

4. Confirm with the user that sign-in and desktop access are normal.
   Expected result: User reports normal access.

5. Continue monitoring for 30 minutes for new 4771 or 4740 events for FINBRIDGE\\cthompson. [ELEVATED]
   Expected result: No recurrence is observed.

Only close the incident after all verification steps pass.

---

## Rollback

Use this rollback if multiple users begin failing sign-in, if critical automated jobs stop unexpectedly, or if repeated lockouts continue immediately after the fix.

1. Open C:\\Temp\\cthompson_tasks_before.txt on DESKTOP-FB022. [ELEVATED]
   Expected result: Pre-change task list is visible.

2. Re-enable each task listed in C:\\Temp\\cthompson_tasks_before.txt. [ELEVATED]
   Expected result: Previously disabled tasks return to their prior enabled state.

3. Open C:\\Temp\\cthompson_services_before.txt on DESKTOP-FB022. [ELEVATED]
   Expected result: Pre-change service list is visible.

4. Start each service listed in C:\\Temp\\cthompson_services_before.txt. [ELEVATED]
   Expected result: Previously stopped services return to Running state.

5. Disable FINBRIDGE\\cthompson account in ADUC. [ELEVATED]
   Expected result: Lockout noise for the account stops while escalation begins.

6. Force sign-out on any active sessions for FINBRIDGE\\cthompson on DESKTOP-FB022 and the 10.10.8.112 host. [ELEVATED]
   Expected result: Active sessions for the affected account are terminated.

7. Reset FINBRIDGE\\cthompson to a new random 24-character temporary password and keep the account disabled. [ELEVATED]
   Expected result: Unknown stale credentials can no longer authenticate while investigation continues.

8. Open a Priority 1 escalation to Identity Engineering with event evidence for 4771, 4776, 4625, 4740, 4722, and 4624. [ELEVATED]
   Expected result: Ownership is transferred with complete forensic context.

---

## Notes

- This incident pattern indicates stale credentials replayed from more than one source.
- Do not unlock the account before credential replay sources are contained.
- If IP 10.10.8.112 resolves to infrastructure (for example, jump host or middleware), involve the platform owner before removing credentials.
- If the user has mobile device mail profiles, remove and re-add the account profile after password reset to avoid new replay.
- If the account is repeatedly re-locked within 5 minutes, keep the account disabled and continue source isolation before any additional unlock.
- Related records:
  - RCA-cthompson-login-lockout-resolution-20260806.md
  - known-error-cthompson-login-lockout-20260806.md
  - cthompson-login-failure-ranked-hypotheses-20260806.md
  - cthompson-incident-communications-20260806.md
  - cthompson-login-closure-note-20260806.md
