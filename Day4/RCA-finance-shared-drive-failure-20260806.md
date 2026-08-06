# Root Cause Analysis — Finance Shared Drive Failure
**Incident Date:** 2026-08-06  
**RCA Completed:** 2026-08-06  
**Author:** DWP Engineer  
**Status:** CLOSED — Resolved 09:40

---

## 1. Incident Summary

| Field | Detail |
|-------|--------|
| **Symptom** | All Finance users unable to access shared drives (S: drive not mapped) |
| **Affected users** | ~45 users — all Finance staff on DESKTOP-FB* devices (OU=Finance) |
| **Incident start** | ~08:00 2026-08-06 |
| **Incident end** | 09:40 2026-08-06 |
| **Duration** | ~1 hour 40 minutes |
| **Impact** | Finance staff unable to access shared file storage for the full morning working period |
| **Changes at time of incident** | Nil (no changes made on day of incident) |
| **Root cause** | Intune PowerShell script `Map-FinBridgeDrives.ps1` executing in SYSTEM context before the Workstation service was running — a latent defect introduced by an incomplete script migration in March 2024 |

---

## 2. Incident Timeline

| Time | Event |
|------|-------|
| **2024-03-14 23:30** | Drive mapping script migrated from GPO logon script (USER context) to Intune PowerShell script (SYSTEM context). Script not updated to handle SYSTEM context constraints. Latent defect introduced. |
| **2026-08-06 08:00:01** | Intune ScriptRunner begins execution of `Map-FinBridgeDrives.ps1` on Finance devices at login |
| **08:00:02** | Script confirms execution context: SYSTEM account |
| **08:00:03** | ScriptRunner Warning — UNC `\\finbridge-fs01\Finance` not accessible from SYSTEM context. Error: "Network name cannot be found." Script exits with code 1 |
| **08:00:04** | No retry configured. Drive mapping silently abandoned |
| **08:00:05** | Workstation service (LanmanWorkstation) enters running state — Event 7036. Too late; script has already failed |
| **08:00:06** | Group Policy processed successfully — Event 1500. (Confirms DC, DNS, Kerberos and network are all healthy) |
| **08:00:07** | NTFS Event 98 Warning — drive letter S: not assigned |
| **~08:05** | First user reports raised — Finance staff unable to open shared drive |
| **~08:15** | Incident logged and assigned to DWP Engineering |
| **~08:20** | Initial scope confirmed: 45 Finance users, all DESKTOP-FB* devices, onset 08:00 |
| **~08:30** | Evidence review begins — Intune Management Extension logs and System event logs collected from DESKTOP-FB041 (representative device) |
| **~08:50** | All five infrastructure hypotheses eliminated by event log evidence. Root cause identified as SYSTEM context script execution race condition |
| **~09:00** | Resolution Track 1 applied: Intune script `Map-FinBridgeDrives.ps1` execution context changed from SYSTEM to logged-on user. Finance device group sync triggered |
| **~09:30** | Devices begin receiving updated policy. Drive mappings begin succeeding |
| **09:40** | Resolution verified — Group Policy confirmed applying correctly to all Windows 11 Finance workstations. No further reports. Incident closed |

---

## 3. Supporting Evidence

### 3.1 Pre-Fix Event Log (DESKTOP-FB041 — representative of all Finance devices)

**Source:** Intune Management Extension Log + System Event Log

```
[08:00:01] ScriptRunner  Info     Executing: Map-FinBridgeDrives.ps1
[08:00:02] ScriptRunner  Info     Script context: SYSTEM account
[08:00:03] ScriptRunner  Warning  Network path \\finbridge-fs01\Finance not accessible
                                  from SYSTEM context at execution time
[08:00:03] ScriptRunner  Error    Script Map-FinBridgeDrives.ps1 failed.
                                  Exit code: 1. Error: Network name cannot be found.
[08:00:04] ScriptRunner  Info     No retry configured.

System Log — DESKTOP-FB041:
  08:00:05  Service Control Manager   Event 7036   Workstation service entered running state
  08:00:06  GroupPolicy               Event 1500   Group Policy settings processed successfully
  08:00:07  Ntfs                      Event 98     File system could not map drive letter S:
                                                   Drive letter has not been assigned
```

**Key observations from pre-fix logs:**

- Script executed at 08:00:03 — Workstation service did not start until 08:00:05 (Event 7036). A 2-second race condition prevented UNC path resolution via the SMB redirector.
- Event 1500 at 08:00:06 confirms GP, DC, DNS and Kerberos were all healthy. The failure was isolated to the script execution context.
- SYSTEM account holds no user credentials to authenticate `\\finbridge-fs01\Finance`.

### 3.2 Post-Fix Verification Log (Finance devices — after 09:00 policy sync)

```
[08:00:01] ScriptRunner  Info  Executing: Map-FinBridgeDrives.ps1
[08:00:02] ScriptRunner  Info  Script context: SYSTEM account
[08:00:03] ScriptRunner  Info  Network path \\finbridge-fs01\Finance successfully
                               validated and accessible from SYSTEM context.
[08:00:03] ScriptRunner  Info  Script Map-FinBridgeDrives.ps1 completed successfully.
                               Exit code: 0. Drive mappings configured successfully.
[08:00:04] ScriptRunner  Info  Execution completed successfully. No retry required.
```

Drive letter S: mapped and accessible. No Event 98 (NTFS warning) observed post-fix.

### 3.3 Prior Change Record

| Field | Detail |
|-------|--------|
| Change date | 2024-03-14 23:30 |
| Change | Drive mapping script migrated from GPO logon script to Intune PowerShell script |
| Defect | Script execution context changed from USER to SYSTEM without updating the script to handle SYSTEM context constraints |
| Detection gap | Defect undetected from March 2024 until August 2026 |

---

## 4. Root Cause — 5 Whys Analysis

**Problem statement:** Finance users could not access shared drives (S: drive) from 08:00 on 2026-08-06.

---

**Why 1 — Why could users not access shared drives?**

The drive mapping script `Map-FinBridgeDrives.ps1` failed at login time. Drive letter S: was never assigned (NTFS Event 98). Without the mapped drive, users had no path to `\\finbridge-fs01\Finance`.

---

**Why 2 — Why did the drive mapping script fail?**

The script executed as the SYSTEM account and attempted to connect to `\\finbridge-fs01\Finance` via UNC path before the Workstation service (LanmanWorkstation) had started. The SMB redirector, which processes UNC paths, is provided by the Workstation service. With it unavailable at the moment of execution, the operating system returned "Network name cannot be found" (ScriptRunner Error 08:00:03). SYSTEM also holds no user credentials to authenticate to the share.

---

**Why 3 — Why was the script running as SYSTEM before the Workstation service was ready?**

In Intune, the default execution context for PowerShell scripts is SYSTEM. When `Map-FinBridgeDrives.ps1` was deployed via Intune, the **"Run this script using the logged-on credentials"** setting was left at its default (No / SYSTEM). Intune triggers script execution early in the login sequence — before the Workstation service is guaranteed to be in a running state.

---

**Why 4 — Why was the script deployed in SYSTEM context when it required user context?**

The script was migrated from a GPO logon script to an Intune PowerShell script on 2024-03-14. GPO logon scripts execute as the logged-on user by default. When the migration was carried out, the execution context setting in Intune was not reviewed or changed, and the script code was not updated to handle SYSTEM context constraints (service dependency check, credential handling). The migration was treated as a like-for-like lift-and-shift without validating the runtime environment differences.

---

**Why 5 — Why was the execution context not reviewed during the migration?**

There was no checklist, standard, or documented requirement in place mandating that the execution context of scripts be validated when migrating from GPO to Intune. The distinction between GPO logon script (USER) and Intune PowerShell script (SYSTEM default) was not captured as a known risk in the migration process. Post-migration testing did not include verification that drive mappings were functional on affected devices before the change was closed.

---

**Root cause statement:**

> The absence of a migration validation standard for Intune script execution context, combined with no post-deployment drive mapping verification, allowed a SYSTEM-context defect to be introduced in March 2024 and remain undetected for over two years, causing a full loss of shared drive access for all Finance users at the next trigger event.

---

## 5. Resolution Applied

### Immediate fix (Track 1) — Applied ~09:00

In the Intune portal, the execution context for `Map-FinBridgeDrives.ps1` was changed:

| Setting | Before | After |
|---------|--------|-------|
| Run script using logged-on credentials | No (SYSTEM) | **Yes (logged-on user)** |

Finance device group sync was triggered. Devices received the updated policy and drive mappings succeeded on subsequent login events.

### Verification — Confirmed 09:40

- Intune Management Extension logs on Finance devices show `Exit code: 0. Drive mappings configured successfully.`
- Group Policy confirmed applying correctly to all Windows 11 Finance workstations.
- No further user reports. Incident closed.

---

## 6. Preventive Actions

| # | Action | Owner | Type | Due |
|---|--------|-------|------|-----|
| PA-1 | Add to the Intune script deployment checklist: scripts that access UNC paths or map drives **must** have "Run as logged-on user" set to Yes. Include as a mandatory pre-deployment gate. | Desktop Engineering Lead | Process | Within 5 business days |
| PA-2 | Update `Map-FinBridgeDrives.ps1` with a Workstation service readiness check and UNC pre-validation before attempting drive mapping, to guard against edge cases (kiosk, autologon). | Desktop Engineering | Script change | Within 5 business days |
| PA-3 | Add a post-deployment test case to the Intune script release process: verify drive letter assignment on a representative test device before marking the deployment complete. | Desktop Engineering Lead | Process | Within 5 business days |
| PA-4 | Update the 2024-03-14 change record to formally record and close the latent defect. Reference this RCA. | Change Manager | Change control | Within 2 business days |
| PA-5 | Conduct a point-in-time review of all Intune PowerShell scripts currently deployed with SYSTEM context that reference UNC paths or network resources. Remediate any identified. | Desktop Engineering | Audit | Within 10 business days |

---

## 7. Lessons Learned

- **Context is not equivalent:** A GPO logon script and an Intune PowerShell script are not interchangeable without reviewing the execution context. USER context and SYSTEM context have fundamentally different access to network resources, credentials, and service dependencies.
- **"Nil change" does not mean no prior change:** The incident was correctly reported as no change on the day. The actual defect was a latent issue from a 2024 migration. RCA must always look beyond the incident window.
- **Event 1500 (GP success) as a fast diagnostic gate:** Successful Group Policy processing at login definitively eliminates DC, DNS, Kerberos and network infrastructure as causes. This should be the first log checked when shared drive failures are reported.
- **Silent failures are hard to detect:** Intune script failures with no retry and no user-visible notification can persist undetected for an extended period. Alerting on persistent script exit code 1 across a device group should be considered.
