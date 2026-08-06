# Known Error Record: Third-Floor GPO Login Failure

Symptom : Users on affected Windows 11 workstations could not complete normal domain logon policy processing, with Group Policy reported as unavailable. On affected machines, policy processing failed because the client could not reach required domain policy paths.

Cause : The verified root cause was an outdated DNS server still configured in the Floor 3 DHCP scope after DNS migration. Affected clients received 10.10.3.250 (decommissioned), which caused domain controller name-resolution failure and downstream secure-channel and SYSVOL access failures.

Scope : The incident affected 3 Windows 11 workstations on Floor 3 in the Finance segment during approximately 07:40 to 09:40. A comparator workstation in the same OU with correct DNS (10.10.0.10) was unaffected.

Workaround : Apply correct DNS on affected clients immediately so they can resolve the domain controller, then refresh client network state. In this incident pattern, clients with correct DNS configuration processed Group Policy successfully.

Permanent fix: Update the Floor 3 DHCP scope to use active DNS (10.10.0.10) and remove deprecated DNS entries. Then renew affected client leases, refresh client DNS state, and verify successful secure channel and Group Policy processing.

How to spot it: Look for Netlogon Event 5719 (no domain controller available, DNS query no response), DNS Client Event 1014 (name resolution timed out), GroupPolicy Events 1058 and 1030 (cannot access/query policy), and GroupPolicy Event 1129 (no DC connectivity). Recovery is confirmed by Netlogon Event 5717 (secure channel established, DNS response successful) and GroupPolicy Event 1502 (gpt.ini read from SYSVOL, status 0x0).
