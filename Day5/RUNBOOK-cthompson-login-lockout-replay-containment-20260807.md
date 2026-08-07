# Runbook - Resolve Single-User AD Lockout from Multi-Source Credential Replay

Title: Runbook - Resolve Single-User AD Lockout from Multi-Source Credential Replay
Version: 1.0
Date: 07/08/2026
Author: Sathishbabu
reviewed: self
status: draft
change: initial version from RCA

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

1. Sign in to a Domain Controller with an account that has Security log read rights. [ELEVATED]
   Expected result: You are on a Domain Controller desktop session.

2. Open Event Viewer from Start > Windows Administrative Tools > Event Viewer. [ELEVATED]
   Expected result: Event Viewer opens.

3. Select Windows Logs > Security in the left navigation tree. [ELEVATED]
   Expected result: Security events populate in the center pane.

4. Select Action > Filter Current Log in the right Actions pane. [ELEVATED]
   Expected result: The Filter Current Log dialog opens.

5. Enter 4776,4625,4740,4771 in the Event IDs field. [ELEVATED]
   Expected result: The Event IDs field shows 4776,4625,4740,4771.

6. Select OK in the Filter Current Log dialog. [ELEVATED]
   Expected result: Security view shows only events with IDs 4776, 4625, 4740, and 4771.

7. Select Find in the right Actions pane. [ELEVATED]
   Expected result: The Find dialog opens.

8. Enter FINBRIDGE\\cthompson in the Find what field. [ELEVATED]
   Expected result: The Find dialog shows FINBRIDGE\\cthompson.

9. Select Find Next in the Find dialog. [ELEVATED]
   Expected result: An event containing FINBRIDGE\\cthompson is highlighted.

10. Open the latest Event ID 4740 for FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: The event details pane shows Caller Computer Name.

11. Record the Caller Computer Name from Event ID 4740 in the incident ticket. [ELEVATED]
    Expected result: The ticket contains Caller Computer Name = DESKTOP-FB022.

12. Open the latest Event ID 4771 for FINBRIDGE\\cthompson. [ELEVATED]
    Expected result: The event details pane shows Source Network Address.

13. Record the Source Network Address from Event ID 4771 in the incident ticket. [ELEVATED]
    Expected result: The ticket contains Source Network Address = 10.10.8.112.

14. Open Active Directory Users and Computers from Start > Windows Administrative Tools > Active Directory Users and Computers. [ELEVATED]
    Expected result: ADUC opens.

15. Select Action > Find in ADUC. [ELEVATED]
    Expected result: Find Users, Contacts, and Groups dialog opens.

16. Enter cthompson in the Name field. [ELEVATED]
    Expected result: The Name field shows cthompson.

17. Select Find Now. [ELEVATED]
    Expected result: FINBRIDGE\\cthompson appears in the search results list.

18. Open the FINBRIDGE\\cthompson user object from the search results. [ELEVATED]
    Expected result: User properties window opens.

19. Select the Account tab in user properties. [ELEVATED]
    Expected result: Account settings are visible.

20. Check Account is disabled. [ELEVATED]
    Expected result: Account is marked as disabled.

21. Select Apply in user properties. [ELEVATED]
    Expected result: Account disable change saves without error.

22. Open DHCP from Start > Windows Administrative Tools > DHCP. [ELEVATED]
    Expected result: DHCP console opens.

23. Navigate to DHCP > <server-name> > IPv4 > Address Leases for the 10.10.8.0/24 scope. [ELEVATED]
    Expected result: Active lease table is displayed.

24. Locate IP Address 10.10.8.112 in Address Leases. [ELEVATED]
    Expected result: A lease row for 10.10.8.112 is visible.

25. Record the Host Name value from lease 10.10.8.112 in the incident ticket. [ELEVATED]
    Expected result: The second-source hostname is documented in the ticket.

26. Open Remote Desktop Connection from Start > Run > mstsc. [ELEVATED]
    Expected result: Remote Desktop Connection dialog opens.

27. Connect to DESKTOP-FB022 with administrative credentials. [ELEVATED]
    Expected result: Remote desktop session to DESKTOP-FB022 opens.

28. Open Control Panel > User Accounts > Credential Manager > Windows Credentials on DESKTOP-FB022. [ELEVATED]
    Expected result: Windows credential entries are listed.

29. Remove every credential entry that contains FINBRIDGE\\cthompson on DESKTOP-FB022. [ELEVATED]
    Expected result: No credential entries remain for FINBRIDGE\\cthompson on DESKTOP-FB022.

30. Open PowerShell as Administrator on DESKTOP-FB022. [ELEVATED]
    Expected result: Elevated PowerShell window opens.

31. Run this command on DESKTOP-FB022: Get-ScheduledTask | Where-Object {$_.Principal.UserId -eq 'FINBRIDGE\\cthompson'} | Select-Object TaskPath,TaskName,State | Export-Csv C:\\Temp\\cthompson_tasks_before.csv -NoTypeInformation. [ELEVATED]
    Expected result: File C:\\Temp\\cthompson_tasks_before.csv is created.

32. Run this command on DESKTOP-FB022: Import-Csv C:\\Temp\\cthompson_tasks_before.csv | ForEach-Object { Disable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName }. [ELEVATED]
    Expected result: All listed tasks are disabled without command errors.

33. Run this command on DESKTOP-FB022: Get-CimInstance Win32_Service | Where-Object {$_.StartName -eq 'FINBRIDGE\\cthompson'} | Select-Object Name,DisplayName,State,StartName | Export-Csv C:\\Temp\\cthompson_services_before.csv -NoTypeInformation. [ELEVATED]
    Expected result: File C:\\Temp\\cthompson_services_before.csv is created.

34. Run this command on DESKTOP-FB022: Import-Csv C:\\Temp\\cthompson_services_before.csv | ForEach-Object { Stop-Service -Name $_.Name -Force }. [ELEVATED]
    Expected result: All listed services are stopped without command errors.

35. Open Remote Desktop Connection from Start > Run > mstsc. [ELEVATED]
    Expected result: Remote Desktop Connection dialog opens.

36. Connect to the hostname recorded in Step 25 with administrative credentials. [ELEVATED]
    Expected result: Remote desktop session to the second source host opens.

37. Open Control Panel > User Accounts > Credential Manager > Windows Credentials on the second source host. [ELEVATED]
    Expected result: Windows credential entries are listed.

38. Remove every credential entry that contains FINBRIDGE\\cthompson on the second source host. [ELEVATED]
    Expected result: No credential entries remain for FINBRIDGE\\cthompson on the second source host.

39. Return to ADUC and open FINBRIDGE\\cthompson properties. [ELEVATED]
    Expected result: User properties window opens.

40. Select Reset Password in user properties. [ELEVATED]
    Expected result: Reset Password dialog opens.

41. Enter a temporary 24-character password in New password and Confirm password. [ELEVATED]
    Expected result: Both password fields are populated.

42. Select OK in the Reset Password dialog. [ELEVATED]
    Expected result: ADUC confirms password reset completed.

43. Select the Account tab in user properties. [ELEVATED]
    Expected result: Account settings are visible.

44. Check User must change password at next logon. [ELEVATED]
    Expected result: The checkbox is selected.

45. Clear Account is disabled. [ELEVATED]
    Expected result: The account is no longer marked disabled.

46. Check Unlock account. [ELEVATED]
    Expected result: Unlock option is selected.

47. Select Apply in user properties. [ELEVATED]
    Expected result: Account enable and unlock changes save without error.

48. Send the temporary password to the user through the approved secure channel.
    Expected result: User confirms receipt of temporary password.

49. Ask the user to sign in to DESKTOP-FB022 with the temporary password.
    Expected result: Windows prompts for immediate password change.

50. Ask the user to set a new personal password at the prompt.
    Expected result: User reaches desktop successfully after password change.

---

## Verification

1. Open Event Viewer on a Domain Controller and select Windows Logs > Security. [ELEVATED]
   Expected result: Security events are visible in the center pane.

2. Select Action > Filter Current Log and enter 4624 in Event IDs. [ELEVATED]
   Expected result: Security view shows only successful logon events.

3. Select Find and search for FINBRIDGE\\cthompson. [ELEVATED]
   Expected result: At least one Event ID 4624 entry for FINBRIDGE\\cthompson is highlighted.

4. Open the latest matching 4624 event and check Logon Type in Event Data. [ELEVATED]
   Expected result: Logon Type equals 2.

5. Check Workstation Name in that same 4624 event. [ELEVATED]
   Expected result: Workstation Name equals DESKTOP-FB022.

6. Select Action > Filter Current Log and enter 4771,4776,4625,4740 in Event IDs. [ELEVATED]
   Expected result: Security view shows only failure and lockout events.

7. Run this PowerShell command on the Domain Controller: (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4771,4776,4625,4740; StartTime=(Get-Date).AddMinutes(-30)} | Where-Object {$_.Message -match 'FINBRIDGE\\\\cthompson'}).Count. [ELEVATED]
    Expected result: Command output is 0.

8. Ask the user to lock and unlock their Windows session once on DESKTOP-FB022.
   Expected result: The user unlocks successfully with no bad-password prompt loops.

9. Wait 30 minutes from the successful 4624 timestamp before the final log check. [ELEVATED]
    Expected result: The 30-minute observation window is complete.

10. Select Action > Refresh in the filtered Security log after the 30-minute window. [ELEVATED]
     Expected result: No new 4771, 4776, 4625, or 4740 entries for FINBRIDGE\\cthompson appear after the successful 4624 event.

Only close the incident after all verification steps pass.

---

## Rollback

Use this rollback when the remediation causes wider impact. Target completion time is under 3 minutes.

1. Open Active Directory Users and Computers from Start > Windows Administrative Tools > Active Directory Users and Computers on a Domain Controller. [ELEVATED]
   Expected result: ADUC opens.

2. Open FINBRIDGE\\cthompson user properties in ADUC. [ELEVATED]
   Expected result: User properties window opens.

3. Select Account tab > check Account is disabled > select Apply. [ELEVATED]
   Expected result: The account is disabled and lockout traffic is contained.

4. Open PowerShell as Administrator on DESKTOP-FB022 from Start > Windows PowerShell > Windows PowerShell (Admin). [ELEVATED]
   Expected result: Elevated PowerShell window opens.

5. Run this command on DESKTOP-FB022: if (Test-Path C:\\Temp\\cthompson_tasks_before.csv) { Import-Csv C:\\Temp\\cthompson_tasks_before.csv | ForEach-Object { Enable-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName } }. [ELEVATED]
   Expected result: Previously disabled tasks are re-enabled, or command exits cleanly if no CSV exists.

6. Run this command on DESKTOP-FB022: if (Test-Path C:\\Temp\\cthompson_services_before.csv) { Import-Csv C:\\Temp\\cthompson_services_before.csv | ForEach-Object { Start-Service -Name $_.Name } }. [ELEVATED]
   Expected result: Previously stopped services are restarted, or command exits cleanly if no CSV exists.

7. Open your ITSM portal (ServiceNow > Incident > Create New) and create a P1 incident assigned to Identity Engineering. [ELEVATED]
   Expected result: A P1 escalation ticket is created with owner set to Identity Engineering.

8. Paste this evidence line into the P1 ticket: "Rollback executed; account disabled; restore commands run on DESKTOP-FB022; investigate events 4771, 4776, 4625, 4740, 4722, 4624." [ELEVATED]
   Expected result: Escalation ticket contains the minimum forensic handoff data.

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
