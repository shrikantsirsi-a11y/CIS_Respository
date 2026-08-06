# Third-Floor GPO Incident Communications

Date: 2026-08-06

## Audience 1 - Non-technical executive

Your access is restored, and your data remains safe. From about 07:40 to 09:40, three Windows 11 devices on Floor 3 could not complete sign-in settings because they were given an outdated server address after overnight migration work. We corrected the address at the network source, refreshed the affected devices, and confirmed full recovery at 09:40. No further issues were reported. You do not need to do anything unless the issue returns.

## Audience 2 - Affected end-user team (non-technical)

Hi team, between 07:40 and 09:40, three Floor 3 Windows 11 PCs could not finish sign-in because they received an old server address after overnight migration work. We fixed the network setting, refreshed the affected PCs, and confirmed recovery at 09:40, with no further issues reported. If you see the same problem, restart once and try again; if it still fails, report the time and your PC name. Please contact the DWP Service Desk.

## Audience 3 - Engineer-to-engineer internal note

Incident summary:
- Impact window: approximately 07:40 to 09:40
- Scope: 3 affected Windows 11 workstations on Floor 3 (Finance segment)
- Symptom: GP unavailable at logon, DC discovery failures

Root cause:
- Floor 3 DHCP scope retained decommissioned DNS reference post-migration.
- Affected clients received old DNS (10.10.3.250) instead of active DNS (10.10.0.10), causing DC lookup timeouts and downstream GP/SYSVOL failures.

Exact action taken:
1. Updated DHCP scope option 006 for Floor 3 to active DNS 10.10.0.10.
2. Removed deprecated DNS entries from the same scope.
3. Renewed client lease and refreshed client DNS state on affected endpoints.
4. Re-tested DC resolution/secure channel and forced GP processing validation.

Config detail:
- Bad assigned DNS observed: 10.10.3.250 (deprecated/decommissioned in migration wave)
- Correct DNS baseline: 10.10.0.10
- Comparative unaffected host had correct DNS preconfigured and processed GP successfully.

Verification:
- 09:40:08 Netlogon Event 5717 Info: secure channel established with FINBRIDGE; FINBRIDGE-DC01 DNS response successful.
- 09:40:09 GroupPolicy Event 1502 Info: GP processed successfully; gpt.ini read from SYSVOL; status 0x0.
- Post-fix status: no additional issues reported.

Preventive action required:
1. Daily DHCP scope audit for deprecated DNS IPs across all subnets.
2. Mandatory migration gate: verify DHCP option 006 and option 015 before closure.
3. Post-change synthetic checks per critical subnet:
- SRV lookup for _ldap._tcp.dc._msdcs domain
- nltest DC discovery
- SYSVOL path accessibility test
4. Alerting on event spikes by subnet for 5719, 1014, 1058, 1030, 1129.
