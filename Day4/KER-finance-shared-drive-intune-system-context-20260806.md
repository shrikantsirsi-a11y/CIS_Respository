# Known Error Record — Finance Shared Drive Failure (Intune SYSTEM Context)
**KB Reference:** KER-Finance-SharedDrive-20260806  
**Status:** Active  
**Date Raised:** 2026-08-06  
**Source RCA:** RCA-finance-shared-drive-failure-20260806.md

---

**Symptom:**  
Users are unable to access their shared drive (S:) at login. The drive letter is not mapped and no error is shown to the user.

**Cause:**  
The Intune PowerShell script `Map-FinBridgeDrives.ps1` executes as the SYSTEM account before the Workstation service (LanmanWorkstation) has started, preventing UNC path resolution to `\\finbridge-fs01\Finance`. The SYSTEM account also holds no user credentials to authenticate to the share. This execution context mismatch was introduced on 2024-03-14 when the script was migrated from a GPO logon script (USER context) to an Intune PowerShell script without setting "Run as logged-on user: Yes."

**Scope:**  
All Finance staff on DESKTOP-FB* devices in OU=Finance (approximately 45 users). Any other Intune-managed device group where a drive mapping script is deployed with the default SYSTEM execution context is potentially affected by the same class of defect.

**Workaround:**  
Instruct affected users to log off and log back on after the Intune script context has been corrected. If the script has not yet been corrected, users can manually map the drive by running `net use S: \\finbridge-fs01\Finance` from a Command Prompt while logged in as their own account.

**Permanent Fix:**  
In the Intune portal, navigate to Devices → Scripts and remediations → Platform scripts → `Map-FinBridgeDrives.ps1` → Properties → Settings and set **"Run this script using the logged-on credentials"** to **Yes**. Trigger a sync to the affected device group. Additionally, update the script to include a Workstation service readiness check and UNC pre-validation before attempting drive mapping.

**How to Spot It:**  
Check `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` for `Script context: SYSTEM account` followed by exit code 1 and the message `"Network name cannot be found"` against `Map-FinBridgeDrives.ps1`. In the System event log, confirm NTFS **Event ID 98** (drive letter not assigned) at login time and **Event ID 7036** (Workstation service entering running state) appearing *after* the ScriptRunner failure timestamp. The presence of **Event ID 1500** (Group Policy processed successfully) in the same login window rules out DC, DNS, Kerberos, and network infrastructure as contributing causes.
