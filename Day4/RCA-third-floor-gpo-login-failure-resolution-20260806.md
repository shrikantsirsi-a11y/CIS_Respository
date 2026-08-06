# RCA: Third-Floor Windows 11 Logon and Group Policy Failure

Document date: 2026-08-06  
Incident date (from event logs): 2024-03-15  
Prepared by: DWP Engineering

## 1. Executive Summary
Between approximately 07:40 and 09:40, three Windows 11 workstations on Floor 3 were unable to process domain Group Policy at logon. The immediate symptom was Group Policy unavailability and domain controller discovery failures. Investigation confirmed affected clients were assigned a decommissioned DNS server through DHCP scope configuration for the Floor 3 subnet. After DHCP DNS scope correction and client renewal, domain secure channel and Group Policy processing recovered. Service was confirmed restored at 09:40, and no further issues were reported.

## 2. Scope and Impact
- Affected population: 3 Windows 11 workstations on Floor 3 (Finance OU segment)
- Unaffected comparator: 1 peer workstation with manually corrected DNS configuration
- User impact:
  - Delayed or failed policy application at startup/logon
  - Potentially inconsistent security and user environment settings during incident window
- Start time: ~07:40
- Resolution verification: 09:40
- Reported residual issues after fix: None

## 3. Supporting Evidence

### 3.1 Failure Evidence (Affected Host: DESKTOP-FB031)
- 07:40:08 Netlogon Event 5719 (Error)
  - Could not establish secure channel to FINBRIDGE; no domain controller available.
  - DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 GroupPolicy Event 1058 (Error)
  - Failed to access SYSVOL policy path and gpt.ini.
  - Status included path-not-found failure context.
- 07:40:10 GroupPolicy Event 1030 (Warning)
  - Could not query list of Group Policy objects.
- 07:40:12 GroupPolicy Event 1129 (Error)
  - No network connectivity to domain controller for Group Policy processing.
- 07:41:05 DNS Client Event 1014 (Warning)
  - DNS resolution timeout for FINBRIDGE-DC01.finbridge.local.
  - Configured DNS servers did not respond.
- 07:42:18 DHCP Client Event 50036 (Information)
  - Lease granted with DNS server 10.10.3.250 (decommissioned old DNS).
- 07:44:01 GroupPolicy Event 1129 (Error)
  - Repeated Group Policy failure due to DC connectivity issue.

### 3.2 Comparator Evidence (Unaffected Host: DESKTOP-FB029)
- 07:40:05 DHCP Client Event 50036
  - DNS assigned: 10.10.0.10 (current valid DNS)
- 07:40:11 GroupPolicy Event 1500 (Information)
  - Group Policy processed successfully.

Interpretation:
- Same environment and timing, different DNS assignment outcome.
- Strong isolation of failure domain to DNS assignment path, not domain-wide AD outage.

### 3.3 Recovery Verification Evidence
- 09:40:08 Netlogon Event 5717 (Information)
  - Secure channel successfully established with FINBRIDGE domain.
  - FINBRIDGE-DC01 responded successfully to DNS queries.
- 09:40:09 GroupPolicy Event 1502 (Information)
  - Group Policy processed successfully.
  - gpt.ini accessed successfully from SYSVOL.
  - Status 0x0 (Success).

## 4. Incident Timeline (UTC offset not supplied)
- 07:40:02: NLA service running (network stack available).
- 07:40:08: Netlogon secure channel failure; DC DNS lookup fails.
- 07:40:09 to 07:40:12: Group Policy access/query/connectivity errors (1058, 1030, 1129).
- 07:41:05: DNS timeout confirms resolver path failure (1014).
- 07:42:18: DHCP lease confirms deprecated DNS assignment from Floor 3 scope.
- 07:44:01: Repeated GP failure confirms persistence.
- 09:40:08: Netlogon confirms secure channel restored (5717).
- 09:40:09: GroupPolicy confirms successful processing and SYSVOL access (1502).
- Post 09:40: No additional user issues reported.

## 5. Root Cause Statement
The Floor 3 DHCP scope retained a decommissioned DNS server reference after DNS migration. Affected workstations received obsolete DNS settings at startup, failed to resolve domain controller records, and consequently could not establish secure channel or access SYSVOL policy files during Group Policy processing.

## 6. Contributing Factors
- DNS migration wave completed overnight without complete DHCP scope option update for all subnets.
- Partial manual pre-configuration created mixed endpoint behavior, delaying clear detection.
- Lack of pre-change guardrail to validate DHCP scope DNS options against active DNS inventory.

## 7. 5 Whys Analysis
1. Why did users see Group Policy unavailable at logon?
- Because clients could not contact a domain controller and could not read policy files from SYSVOL.

2. Why could clients not contact a domain controller?
- Because DNS resolution for the DC FQDN timed out.

3. Why did DNS resolution time out?
- Because clients were configured with a decommissioned DNS server.

4. Why were clients configured with a decommissioned DNS server?
- Because DHCP scope option 006 for Floor 3 still pointed to the old DNS server after migration.

5. Why was DHCP scope not corrected during migration?
- Because migration execution controls did not include a mandatory post-change DHCP scope validation and sign-off for all impacted subnets.

Primary process root cause:
- Incomplete migration change control and validation for dependent DHCP DNS configuration.

## 8. Resolution Actions Performed
1. Corrected DHCP scope DNS settings for Floor 3 to active DNS server(s).
2. Removed deprecated DNS server entries from scope options.
3. Renewed DHCP lease and refreshed DNS client state on affected endpoints.
4. Re-tested domain controller resolution and secure channel establishment.
5. Forced and verified Group Policy processing success.

## 9. Validation and Closure Criteria
Closure criteria met:
- Netlogon secure channel success logged at 09:40:08 (Event 5717).
- GroupPolicy success logged at 09:40:09 (Event 1502, Status 0x0).
- SYSVOL gpt.ini access confirmed successful.
- No further incidents reported from affected Windows 11 workstations after fix.

## 10. Preventive and Corrective Actions

### 10.1 Immediate Preventive Controls
1. Implement a DHCP scope audit script to flag deprecated DNS IPs across all subnets daily.
2. Add migration checklist gate: DHCP options validation required before change closure.
3. Add post-change synthetic tests from each critical subnet:
- `_ldap._tcp.dc._msdcs.<domain>` SRV resolution
- `nltest /dsgetdc:<domain>`
- `dir \\<domain>\\SYSVOL`

### 10.2 Medium-Term Hardening
1. Establish authoritative CMDB mapping for DNS infrastructure and retirement dates.
2. Integrate DHCP configuration compliance into infrastructure CI/CD or scheduled governance checks.
3. Add alerting for spikes in Event IDs 5719, 1014, 1058, 1030, and 1129 by subnet/floor.

### 10.3 Operational Readiness
1. Publish runbook for "GPO unavailable at logon" triage with decision tree:
- DNS first, then DC discovery, then SYSVOL reachability.
2. Conduct change-window peer review specifically for dependent service updates (DNS, DHCP, AD).
3. Require rollback plan validation that includes DHCP option restoration and endpoint reconvergence testing.

## 11. Residual Risk
- If any additional subnet still references retired DNS infrastructure, similar failures may recur in other floors or OUs.
- Risk level after fix: Low to moderate, pending completion of preventive audits and control gates.

## 12. Final Status
Resolved. Verified at 09:40 with successful Netlogon and Group Policy events. No ongoing issues reported for the affected Windows 11 workstations.
