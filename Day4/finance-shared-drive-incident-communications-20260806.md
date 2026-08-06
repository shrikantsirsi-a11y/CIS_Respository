# Finance Shared Drive Failure — Incident Communications
**Incident:** Finance Shared Drive Failure 2026-08-06  
**Audiences:** Executive / End-user Team / Engineer

---

## Audience 1 — Non-Technical Executive

**Subject: Finance Shared Drive Access — Resolved**

Your team's shared drive access was temporarily unavailable this morning between approximately 08:00 and 09:40. No data was lost and no security risk was involved — the files were safe throughout. The issue was caused by a configuration error in the software that sets up staff workstations at login, which has now been corrected. Access has been fully restored. No action is required from you or your team.

---

## Audience 2 — Affected End-User Team

**Subject: Shared Drive Access This Morning — Fixed**

Hi team,

You may have been unable to access your shared drive (S:) this morning from around 08:00. This was caused by a background setup process that ran too early during login before the system was fully ready — nothing you did caused it, and your files were safe the whole time. The issue was fixed at 09:40 and drives should be working normally now.

If you still cannot see your S: drive, please log off and log back on. If the problem continues, contact the IT Service Desk and reference **INC-Finance-Shared-Drive-20260806**.

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: P1 Finance Shared Drive Failure — RCA Summary and Actions**

**Root cause:** `Map-FinBridgeDrives.ps1` deployed via Intune executing as SYSTEM (default context) at login. Script attempted UNC connection to `\\finbridge-fs01\Finance` at 08:00:03 before LanmanWorkstation entered running state (Event 7036 at 08:00:05). SYSTEM account also holds no user credentials for SMB auth. Result: exit code 1, "Network name cannot be found", no retry configured, S: never assigned (NTFS Event 98). Latent defect — introduced 2024-03-14 when script was migrated GPO logon (USER context) → Intune PowerShell without updating the execution context flag or adding service dependency handling. Event 1500 (GP success) at 08:00:06 eliminated DC/Kerberos/DNS/network as causes.

**Action taken:** Intune portal → Devices → Scripts and remediations → Platform scripts → `Map-FinBridgeDrives.ps1` → Properties → Settings → **"Run this script using the logged-on credentials": changed No → Yes**. Finance device group sync triggered ~09:00.

**Verification:** Post-fix Intune Management Extension logs confirm `Exit code: 0. Drive mappings configured successfully.` GP verified applying correctly to all Windows 11 Finance workstations (DESKTOP-FB*, OU=Finance) by 09:40. No further reports.

**Preventive actions outstanding:**
- **PA-1:** Add to Intune script deployment checklist — any script accessing UNC paths must have "Run as logged-on user: Yes" as a mandatory pre-deployment gate.
- **PA-2:** Harden `Map-FinBridgeDrives.ps1` — add `Get-Service LanmanWorkstation` readiness wait loop and `Test-Path $uncRoot` pre-check before `New-PSDrive`.
- **PA-3:** Add post-deployment test case to Intune script release process — verify drive letter assignment on representative device before closing deployment.
- **PA-4:** Formally close the 2024-03-14 change record with reference to this RCA.
- **PA-5:** Audit all Intune PowerShell scripts currently running as SYSTEM that reference UNC paths — remediate any found within 10 business days.

**If this recurs:** Check `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` for `Script context: SYSTEM account` + exit code 1. Confirm Intune script context setting first before chasing infrastructure. Event 1500 success = DC/DNS/Kerberos are not the cause.
