# Third-Floor Login Failure: Ranked Hypotheses

Date: 2026-08-06  
Analyst: DWP Engineer  
Scope basis: Facts provided only (no additional telemetry)

## Scope Facts
- Symptom: Windows machines report Group Policy not available
- Who: 3 machines on third floor
- Since: Approximately 07:40 this morning
- Change: Nil

## Ranked Top 5 Likely Causes (Most Probable First)

### 1) Third-floor network segment issue to AD services
**Why this fits the scope facts**
- All impacted devices are co-located on the same floor and failed around the same time, which strongly indicates a localized network path issue (switch/VLAN/ACL/uplink) rather than a domain-wide failure.

**Single fastest check**
- From one affected endpoint, test DC reachability on policy-critical ports:
  - `Test-NetConnection <DCName> -Port 445`
  - Optional secondary: `Test-NetConnection <DCName> -Port 389`

### 2) DNS resolution failure on affected clients/subnet
**Why this fits the scope facts**
- Group Policy depends on AD DNS lookups (including SRV records). A bad DNS assignment on that floor/subnet can prevent DC discovery while appearing as a GPO availability problem.

**Single fastest check**
- On one affected endpoint:
  - `nslookup -type=SRV _ldap._tcp.dc._msdcs.<yourdomain>`

### 3) SYSVOL/NETLOGON access failure (SMB/DFS path unavailable)
**Why this fits the scope facts**
- "Group policy not available" commonly occurs when `\\<domain>\SYSVOL` cannot be reached/read. A localized SMB/DFS access issue matches the limited blast radius.

**Single fastest check**
- On one affected endpoint:
  - `dir \\<yourdomain>\SYSVOL`

### 4) AD site/subnet mapping issue sending clients to an unreachable DC
**Why this fits the scope facts**
- Same-floor devices likely share subnet/site. If site mapping is wrong or network path to a selected DC is broken, clients can fail GP processing despite no declared change.

**Single fastest check**
- On one affected endpoint:
  - `nltest /dsgetdc:<yourdomain>`
- Verify selected DC is expected/reachable versus a known-good machine.

### 5) Simultaneous endpoint trust/time issue on those three machines
**Why this fits the scope facts**
- Lower probability, but if these devices drifted in time or lost secure channel, policy processing can fail with similar symptoms.

**Single fastest check**
- On one affected endpoint:
  - `Test-ComputerSecureChannel -Verbose`

## Analyst Note
This is a ranked hypothesis list only. No single cause is confirmed yet.

## Event Evidence Addendum (Incident Window Correlation)

### Source Context
- System Event Log reviewed for affected machine `DESKTOP-FB031`
- Startup window: `2024-03-15 07:40-07:55`
- Impact pattern: `3 of 4` machines in `OU=Finance` affected

### Key Events Captured
- `07:40:02` Service Control Manager `7036`: Network Location Awareness entered running state.
- `07:40:08` Netlogon `5719` (Error): Could not set up secure channel to `FINBRIDGE`; no DC available; DNS query for `FINBRIDGE-DC01.finbridge.local` returned no response.
- `07:40:09` GroupPolicy `1058` (Error): Could not access `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\\gpt.ini`; error `0x3`.
- `07:40:10` GroupPolicy `1030` (Warning): Could not query GPO list; error `0x546`.
- `07:40:11` GroupPolicy `1058` (Error): Repeat SYSVOL access failure.
- `07:40:12` GroupPolicy `1129` (Error): No network connectivity to a domain controller for Group Policy.
- `07:41:05` DNS Client Events `1014` (Warning): Name resolution timed out for `FINBRIDGE-DC01.finbridge.local`; configured DNS servers did not respond.
- `07:42:18` DHCP Client `50036` (Information): Lease `10.10.3.144` from `10.10.0.1`; DNS assigned `10.10.3.250` (decommissioned old DNS).
- `07:44:01` GroupPolicy `1129` (Error): GP failed again due to no DC connectivity.

### Comparator Machine (Same OU, Unaffected)
- `DESKTOP-FB029` `07:40:05` DHCP Client `50036`: DNS assigned `10.10.0.10` (correct new DNS).
- `DESKTOP-FB029` `07:40:11` GroupPolicy `1500` (Information): Group Policy processed successfully.

## Evidence Judgement Against Ranked Hypotheses

### 1) Third-floor network segment issue to AD services
Judgement: `Contradicts`

Reasoning evidence:
- `7036` at `07:40:02` confirms NLA service running (network stack present).
- `50036` at `07:42:18` confirms successful DHCP lease.
- Comparator success (`FB029`) with correct DNS and successful GP (`1500` at `07:40:11`) indicates the path can work when DNS is correct.

### 2) DNS resolution failure on affected clients/subnet
Judgement: `Supports`

Reasoning evidence:
- Netlogon `5719` at `07:40:08` explicitly cites no response to DNS query for DC FQDN.
- DNS Client `1014` at `07:41:05` confirms resolver timeout and non-responsive configured DNS servers.
- DHCP `50036` at `07:42:18` confirms assignment of decommissioned DNS server `10.10.3.250`.

### 3) SYSVOL/NETLOGON access failure (SMB/DFS path unavailable)
Judgement: `Supports`

Reasoning evidence:
- GroupPolicy `1058` at `07:40:09` and `07:40:11` confirms inability to access SYSVOL path and `gpt.ini`.
- GroupPolicy `1030` at `07:40:10` confirms GPO query failure.

### 4) AD site/subnet mapping issue sending clients to an unreachable DC
Judgement: `Contradicts`

Reasoning evidence:
- Netlogon `5719` (`07:40:08`) and DNS `1014` (`07:41:05`) indicate primary failure at DNS resolution stage, before site/DC selection can succeed.

### 5) Simultaneous endpoint trust/time issue on those three machines
Judgement: `Contradicts`

Reasoning evidence:
- Netlogon `5719` and GroupPolicy `1129` (`07:40:12`, `07:44:01`) repeatedly indicate DC reachability/discovery failure, not a primary trust or time skew pattern.

## Supported Hypotheses After Elimination

1. DNS resolution failure on affected clients/subnet.
2. SYSVOL/NETLOGON path unavailable to clients.

## Detailed Resolution Steps

### Resolution Track A: Fix DNS Assignment and Client DNS Health
1. On DHCP, update scope option `006` for the third-floor subnet to active DNS servers only.
2. Remove all decommissioned DNS IPs from that scope.
3. Verify scope option `015` DNS suffix equals `finbridge.local`.
4. Force lease renewal on affected endpoints.
5. Flush resolver cache and re-register client DNS records.
6. Validate AD SRV resolution and DC discovery.
7. Re-run Group Policy processing.
8. Confirm no repeat of events `5719`, `1014`, `1058`, `1030`, `1129` during retest.

Reference commands:
- `Get-DhcpServerv4OptionValue -ScopeId 10.10.3.0`
- `Set-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -DnsServer 10.10.0.10 -DnsDomain finbridge.local`
- `ipconfig /release`
- `ipconfig /renew`
- `ipconfig /flushdns`
- `ipconfig /registerdns`
- `nslookup -type=SRV _ldap._tcp.dc._msdcs.finbridge.local`
- `nltest /dsgetdc:finbridge.local`
- `gpupdate /force`

Validation criteria:
- Affected clients receive DNS `10.10.0.10` (or approved active DNS set).
- SRV lookup returns valid domain controllers.
- Group Policy applies successfully without recurrence of error events.

### Resolution Track B: Restore SYSVOL/NETLOGON Reachability (if still failing after DNS fix)
1. From affected clients, test domain UNC paths to `SYSVOL` and `NETLOGON`.
2. On DC, verify `SYSVOL` and `NETLOGON` shares are published.
3. Confirm `DFSR` and `Netlogon` services are running.
4. Validate client-to-DC SMB (`445`) reachability.
5. Check share and NTFS permissions against domain baseline.
6. Re-run Group Policy and verify successful processing.

Reference commands:
- `dir \\finbridge.local\\sysvol`
- `dir \\finbridge.local\\netlogon`
- `net share | findstr /I "SYSVOL NETLOGON"`
- `Get-Service DFSR,Netlogon`
- `Test-NetConnection FINBRIDGE-DC01 -Port 445`
- `gpupdate /force`

Validation criteria:
- `SYSVOL` and `NETLOGON` are browsable from affected clients.
- Port `445` to selected DC is reachable.
- Group Policy completes successfully (`1500` info event expected).

## Working Conclusion State
No final winner selected in this section by design. Evidence supports both DNS assignment failure and downstream SYSVOL access failure; sequencing indicates DNS remediation first, then share-path verification.
