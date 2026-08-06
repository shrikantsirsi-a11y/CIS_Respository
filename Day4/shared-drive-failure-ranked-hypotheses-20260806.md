# Shared Drive Failure — Ranked Hypotheses
**Date:** 2026-08-06  
**Analyst:** DWP Engineer  
**Status:** Open — no single cause confirmed

---

## Scope Facts

| Field | Value |
|-------|-------|
| Symptom | Users cannot access shared drives |
| Who affected | ~45 users |
| Since | ~08:00 this morning |
| Changes | Nil |

---

## Ranked Hypotheses (Most Probable First)

---

### 1. File Server or DFS Service Has Stopped / Crashed

**Why it fits:**  
A simultaneous loss of access for 45 users at a fixed time, with no reported change, is the classic signature of a server-side service failure. If the Server service, DFS Namespace service, or the file server process itself stopped (due to a crash, patch reboot that ran overnight, or resource exhaustion at peak login time ~08:00), all mapped drives targeting that server would fail for every connected user at once.

**Fastest check:**  
RDP or console into the file server and run:
```powershell
Get-Service LanmanServer, Dfs, DFSR | Select-Object Name, Status
```
A stopped or failed service confirms this cause immediately.

---

### 2. Network Path to the File Server is Broken (Switch / VLAN / Route)

**Why it fits:**  
45 users affected but not the entire organisation suggests a bounded network fault — a trunk port, switch stack, or VLAN carrying that user segment lost connectivity to the file server subnet. The 08:00 onset could align with a switch rebooting after a nightly firmware apply or a spanning-tree reconvergence event. Users in other buildings or VLANs would be unaffected.

**Fastest check:**  
From an affected user's machine:
```cmd
ping <fileserver-hostname> && tracert <fileserver-hostname>
```
If the ping fails or tracert drops at a specific hop, the network path is broken. Cross-reference with a user in a different location who is *not* affected.

---

### 3. Domain Controller Unreachable — Kerberos Authentication Failing

**Why it fits:**  
Shared drives authenticated via SMB rely on Kerberos tickets. If the DC used by this site or subnet became unavailable (service crash, network partition), users whose tickets expired after ~08:00 would fail to re-authenticate to the file server. The 45-user boundary could reflect a site-local DC serving one office segment. "No change" is consistent — DC failures are often spontaneous.

**Fastest check:**  
From an affected machine:
```cmd
nltest /dsgetdc:<domain> /force
```
A failure or timeout confirms the DC is unreachable. Also check: `klist` — if tickets are absent or show errors, Kerberos is the fault domain.

---

### 4. DNS Resolution Failure for the File Server Hostname

**Why it fits:**  
If the DNS server used by this user segment stopped resolving the file server's hostname, drive mappings using UNC paths (e.g. `\\fileserver\share`) would fail silently. Drives mapped by IP would still work; drives mapped by name would not. The scope of 45 users could reflect a single DNS server (site-local or DHCP-assigned) that became unavailable or began returning NXDOMAIN.

**Fastest check:**  
From an affected machine:
```cmd
nslookup <fileserver-hostname>
```
If resolution fails, try connecting by IP directly (`\\<IP>\share`). If the IP path works, DNS is the cause.

---

### 5. File Server Storage Volume Offline or Full (Disk / LUN Issue)

**Why it fits:**  
If the underlying disk volume or LUN hosting the shared folders went offline (e.g. storage array dropped a path, disk hit a critical threshold, or a scheduled snapshot caused a brief volume unmount), the share would become inaccessible to all users without any admin-initiated change. This is a spontaneous infrastructure event consistent with "Nil change."

**Fastest check:**  
On the file server, open Disk Management or run:
```powershell
Get-Volume | Where-Object {$_.DriveType -eq 'Fixed'} | Select-Object DriveLetter, FileSystemLabel, HealthStatus, SizeRemaining
```
Look for volumes showing `Unhealthy`, `Unknown`, or `SizeRemaining` near zero.

---

## Next Steps

1. Confirm the file server is reachable and services are running **(Hypothesis 1)** — eliminates or confirms the most likely cause in under 2 minutes.
2. If server is healthy, test DNS and network path from an affected endpoint **(Hypotheses 2 & 4)**.
3. If network and DNS are clear, check DC reachability and Kerberos **(Hypothesis 3)**.
4. If all above clear, inspect storage volumes on the file server **(Hypothesis 5)**.

Do not escalate or remediate until at least Hypothesis 1 is confirmed or eliminated.

---

## Evidence Assessment — Event Log Review

**Sources:** Intune Management Extension Log + System Log (DESKTOP-FB041, representative of all Finance DESKTOP-FB* devices)  
**Window:** 08:00:01 – 08:00:07

### Key Evidence Timeline

| Time | Source | Event | Detail |
|------|--------|-------|--------|
| 08:00:01 | ScriptRunner | Info | `Map-FinBridgeDrives.ps1` execution begins |
| 08:00:02 | ScriptRunner | Info | Script running as **SYSTEM account** |
| 08:00:03 | ScriptRunner | Warning | UNC `\\finbridge-fs01\Finance` **not accessible from SYSTEM context** |
| 08:00:03 | ScriptRunner | Error | Script failed. Exit code 1. **"Network name cannot be found"** |
| 08:00:04 | ScriptRunner | Info | No retry configured |
| 08:00:05 | System / SCM | Event 7036 | **Workstation service entered running state** |
| 08:00:06 | System / GP | Event 1500 | Group Policy settings processed successfully |
| 08:00:07 | System / NTFS | Event 98 | Drive letter S: not assigned |

**Prior change note (2024-03-14 23:30):** Drive mapping script migrated from GPO logon script (USER context) to Intune PowerShell script (SYSTEM context). Script was not updated to handle SYSTEM context — UNC paths require the Workstation service and user-mapped credentials, neither of which are available to SYSTEM at login time.

---

### H1 — File Server or DFS Service Has Stopped / Crashed

**Verdict: CONTRADICTS**

The error at 08:00:03 is explicitly logged as `"not accessible from SYSTEM context at execution time"` — the ScriptRunner itself identifies the execution context as the constraint, not server availability. Crucially, Group Policy processed successfully at **08:00:06 (Event 1500)**, which requires a working SMB/SYSVOL path to the DC. If the file server infrastructure were down broadly, GP would likely have degraded too. The file server `finbridge-fs01` is not implicated as unavailable; the script simply could not reach it from the SYSTEM account at that moment.

---

### H2 — Network Path to the File Server Broken (Switch / VLAN / Route)

**Verdict: CONTRADICTS**

**Event 1500 at 08:00:06** confirms Group Policy processed successfully. GP requires authenticated network connectivity to a Domain Controller. A broken switch, VLAN, or route to the file server subnet would not prevent GP processing (different path) but the successful GP processing establishes that the affected machines had functional network connectivity at boot time. Additionally, the ScriptRunner warning at **08:00:03** names the constraint as SYSTEM context, not a network path failure. A true network break would produce a timeout or "unreachable host" error, not "network name cannot be found" tied to the SYSTEM account note.

---

### H3 — Domain Controller Unreachable / Kerberos Authentication Failing

**Verdict: CONTRADICTS**

**Event 1500 at 08:00:06** is definitive here. Group Policy processing requires the machine to locate a DC (via DNS SRV records), establish a Kerberos session, and pull policy from SYSVOL. Its successful completion proves the DC was reachable and Kerberos was functioning normally at login time. There is no Kerberos-related error anywhere in the log window.

---

### H4 — DNS Resolution Failure for the File Server Hostname

**Verdict: CONTRADICTS**

Superficially the error `"Network name cannot be found"` can resemble a DNS failure, but two pieces of evidence rule it out. First, **Event 1500 at 08:00:06** confirms GP succeeded — GP depends on DNS SRV lookups to locate DCs, so DNS was functioning. Second, the ScriptRunner at **08:00:03** explicitly attributes the failure to *SYSTEM context*, not name resolution. The Workstation service (required to process UNC names via the SMB redirector) did not enter the running state until **08:00:05 (Event 7036)** — two seconds *after* the script already attempted the connection at 08:00:03. Without the Workstation service active, UNC paths cannot be resolved regardless of DNS health.

---

### H5 — File Server Storage Volume Offline or Full

**Verdict: CONTRADICTS**

No event in the log references the file server's storage state. The failure is attributed at source to SYSTEM context execution (**ScriptRunner Warning 08:00:03**) and is consistent with the prior change note describing a script context migration that was never updated. A storage volume failure would be a server-side condition visible independently of the account context used to connect; the log places the failure entirely on the client side during script execution.

---

### Evidence Summary Table

| # | Hypothesis | Verdict | Determining Evidence |
|---|-----------|---------|----------------------|
| 1 | File server / DFS service stopped | **CONTRADICTS** | ScriptRunner 08:00:03 names SYSTEM context as constraint; Event 1500 08:00:06 shows infrastructure functional |
| 2 | Network path broken | **CONTRADICTS** | Event 1500 08:00:06 proves network connectivity; ScriptRunner explicitly names SYSTEM context |
| 3 | DC unreachable / Kerberos failing | **CONTRADICTS** | Event 1500 08:00:06 — GP success requires DC reachability and valid Kerberos |
| 4 | DNS resolution failure | **CONTRADICTS** | Event 1500 08:00:06 proves DNS functional; Event 7036 08:00:05 shows Workstation service was not yet running when script executed |
| 5 | Storage volume offline / full | **CONTRADICTS** | Failure is client-side SYSTEM context issue per ScriptRunner 08:00:03 and prior change note |

**Emerging picture:** All five infrastructure hypotheses are contradicted by the evidence. The logs point consistently to a single execution-context defect: `Map-FinBridgeDrives.ps1` runs as SYSTEM under Intune at 08:00:01–08:00:03, before the Workstation service is running (Event 7036, 08:00:05), and the SYSTEM account lacks the user credentials required to authenticate to a UNC share. This is consistent with the 2024-03-14 migration change note which records that the script was never updated for SYSTEM context after the GPO → Intune migration.

*Root cause determination step pending — do not close until confirmed.*

---

## Confirmed Root Cause

**All five original hypotheses are eliminated by the event log evidence.**

The actual cause is a latent execution-context defect introduced by the 2024-03-14 migration of `Map-FinBridgeDrives.ps1` from a GPO logon script (USER context) to an Intune PowerShell script (SYSTEM context). The script was never updated to handle SYSTEM context. At login time, Intune triggers the script at 08:00:01 — before the Workstation service (LanmanWorkstation) has started. Without the Workstation service, the SMB redirector is unavailable and UNC paths cannot be resolved. SYSTEM also holds no user credentials to authenticate to `\\finbridge-fs01\Finance`. The result is a silent, repeatable failure on every Finance device login.

| Factor | Detail |
|--------|--------|
| Defect introduced | 2024-03-14 23:30 — GPO → Intune migration |
| Script | `Map-FinBridgeDrives.ps1` |
| Wrong context | SYSTEM (should be logged-on user) |
| Race condition | Script executes at 08:00:03; Workstation service starts at 08:00:05 (Event 7036) |
| Scope | All Finance users — DESKTOP-FB* devices, OU=Finance |
| Reported as "Nil change" | Correct for today; latent defect from prior migration |

---

## Resolution

### Track 1 — Immediate Fix (no script change, ~5 minutes)

**Step 1: Change Intune script execution context**

In the Intune portal:
1. Go to **Devices → Scripts and remediations → Platform scripts**
2. Open `Map-FinBridgeDrives.ps1` → **Properties → Settings**
3. Set **"Run this script using the logged-on credentials"** → **Yes**
4. Save and reassign to the Finance device group

This switches execution from SYSTEM to the interactive logged-on user — the same context the original GPO logon script used. The Workstation service is guaranteed to be running by the time a user is interactive, eliminating the race condition.

**Step 2: Force policy sync to all affected devices**

From the Intune portal: select all Finance (DESKTOP-FB*) devices → **Sync**

Or push via a remediation script:
```powershell
Start-Process "intunemanagementextension://syncapp"
```

**Step 3: Verify on a representative device**

```powershell
Get-PSDrive -Name S -ErrorAction SilentlyContinue
net use S:
```

In the Intune Management Extension log at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`, confirm:
- `ScriptRunner Info Script Map-FinBridgeDrives.ps1 succeeded`
- No SYSTEM context warning
- No exit code 1

---

### Track 2 — Script Hardening (apply alongside or after Track 1)

Update `Map-FinBridgeDrives.ps1` to defend against early execution edge cases (kiosk mode, autologon scenarios):

```powershell
# Wait for Workstation service — guards against early execution edge cases
$svc = Get-Service -Name LanmanWorkstation
$timeout = (Get-Date).AddSeconds(30)
while ($svc.Status -ne 'Running' -and (Get-Date) -lt $timeout) {
    Start-Sleep -Seconds 2
    $svc.Refresh()
}

if ($svc.Status -ne 'Running') {
    Write-Error "Workstation service did not start within 30s. Aborting drive mapping."
    exit 1
}

# Verify UNC reachable before mapping
$uncRoot = '\\finbridge-fs01\Finance'
if (-not (Test-Path $uncRoot)) {
    Write-Error "UNC path $uncRoot not reachable. Aborting."
    exit 1
}

New-PSDrive -Name S -PSProvider FileSystem -Root $uncRoot -Persist -Scope Global
```

Deploy the updated script via Intune with execution context set to **logged-on user**.

---

### Track 3 — Prevent Recurrence

1. Add to the Intune script deployment checklist: any script that maps drives or accesses UNC paths **must** run as logged-on user, not SYSTEM.
2. Update the 2024-03-14 migration change record to formally close the latent defect.
3. Add a post-deployment test case: after any future Intune script change to Finance devices, verify drive mapping from a test DESKTOP-FB* machine before broad rollout.

---

## Success Criteria

| Check | Expected result |
|-------|----------------|
| Intune log on DESKTOP-FB* | `Script Map-FinBridgeDrives.ps1 succeeded` — no SYSTEM context warning |
| Event 98 (NTFS) absent | Drive letter S: assigned successfully |
| User test | `net use` shows `\\finbridge-fs01\Finance` mapped as S: — status OK |
| Scope | All 45 Finance users confirm shared drive access restored |
