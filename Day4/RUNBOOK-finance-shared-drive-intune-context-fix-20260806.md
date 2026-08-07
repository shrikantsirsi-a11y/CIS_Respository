# Runbook — Restore Finance Shared Drive Mapping (Intune Script Context Fix)

**Runbook ID:** RB-FIN-SDRIVE-INTUNE-CONTEXT-20260806  
**Based on RCA:** RCA-finance-shared-drive-failure-20260806.md  
**Last updated:** 2026-08-07  
**Scope:** Finance users on `DESKTOP-FB*` devices (OU=Finance) missing `S:` mapping to `\\finbridge-fs01\Finance`

---

## Prerequisites

1. Confirm you have access to the Intune admin center (`https://intune.microsoft.com`).
2. Confirm your account has permission to edit Intune PowerShell scripts. **[ELEVATED]**
3. Confirm your account has permission to trigger device sync in Intune. **[ELEVATED]**
4. Confirm you can access one representative affected Finance endpoint (example: `DESKTOP-FB041`).
5. Confirm Event Viewer is available on the representative endpoint.
6. Confirm File Explorer is available on the representative endpoint.
7. Confirm the target script name is `Map-FinBridgeDrives.ps1`.

---

## Procedure

1. Open `https://intune.microsoft.com` in a browser.  
   **Expected result:** The Intune admin center sign-in page loads.

2. Sign in with your engineering account.  
   **Expected result:** The Intune admin center home page loads.

3. Open **Devices** in the left navigation.  
   **Expected result:** The Devices blade opens.

4. Open **Scripts and remediations**.  
   **Expected result:** The scripts list page opens.

5. Open **Platform scripts**.  
   **Expected result:** The platform script inventory is displayed.

6. Select `Map-FinBridgeDrives.ps1`.  
   **Expected result:** The script details page opens.

7. Select **Properties**.  
   **Expected result:** Script property values are visible.

8. Select **Edit** next to script settings. **[ELEVATED]**  
   **Expected result:** The script settings form opens in edit mode.

9. Set **Run this script using the logged-on credentials** to **Yes**. **[ELEVATED]**  
   **Expected result:** The field shows **Yes**.

10. Select **Review + save**. **[ELEVATED]**  
    **Expected result:** A review page shows the pending configuration change.

11. Select **Save**. **[ELEVATED]**  
    **Expected result:** A success notification confirms the script update.

12. Open **Devices > All devices**.  
    **Expected result:** The managed devices list opens.

13. Search for `DESKTOP-FB041`.  
    **Expected result:** The representative device appears in results.

14. Open `DESKTOP-FB041`.  
    **Expected result:** The device overview page opens.

15. Select **Sync**. **[ELEVATED]**  
    **Expected result:** A confirmation indicates sync was triggered.

16. Ask the user on `DESKTOP-FB041` to sign out.  
    **Expected result:** The current user session closes.

17. Ask the user on `DESKTOP-FB041` to sign in again.  
    **Expected result:** A fresh user session starts with updated Intune policy evaluation.

18. Open File Explorer on `DESKTOP-FB041`.  
    **Expected result:** File Explorer opens without error.

19. Open drive `S:`.  
    **Expected result:** The `\\finbridge-fs01\Finance` content opens.

---

## Verification

1. Open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on `DESKTOP-FB041`.  
   **Expected result:** The current Intune script execution records are visible.

2. Search the log for `Map-FinBridgeDrives.ps1 completed successfully`.  
   **Expected result:** A matching success entry is present with exit code `0`.

3. Open Event Viewer on `DESKTOP-FB041`.  
   **Expected result:** Event Viewer opens.

4. Check the System log for recent `Ntfs` Event ID `98`.  
   **Expected result:** No new Event ID `98` entries appear after the remediation timestamp.

5. Confirm the `S:` drive opens from File Explorer as the signed-in Finance user.  
   **Expected result:** User can browse and open Finance files.

6. Confirm no new Finance user tickets for missing `S:` mapping are raised for 30 minutes after rollout.  
   **Expected result:** Zero new related incidents are reported.

Only close the incident after all verification steps pass.

---

## Rollback

Use this rollback only if the procedure causes broader impact (for example, login script errors, incorrect mappings, or expanded user impact).

1. Open `Map-FinBridgeDrives.ps1` properties in Intune.  
   **Expected result:** Script settings are visible.

2. Set **Run this script using the logged-on credentials** to **No**. **[ELEVATED]**  
   **Expected result:** The field shows **No**.

3. Select **Review + save**. **[ELEVATED]**  
   **Expected result:** A review page shows the rollback configuration change.

4. Select **Save**. **[ELEVATED]**  
   **Expected result:** A success notification confirms rollback was saved.

5. Trigger **Sync** on the affected representative devices in Intune. **[ELEVATED]**  
   **Expected result:** Sync confirmation appears for each device.

6. Instruct affected users to sign out and sign in again.  
   **Expected result:** Endpoints return to pre-change behavior.

7. Run `net use S: /delete /y` in the affected user session if `S:` points to the wrong location.  
   **Expected result:** Existing `S:` mapping is removed.

8. Run `net use S: \\finbridge-fs01\Finance /persistent:yes` in the affected user session as an immediate access workaround.  
   **Expected result:** `S:` is remapped for that user and Finance files are accessible.

9. Open a P1 escalation to Desktop Engineering for script-level hotfix if more than 5 Finance users still fail after rollback.  
   **Expected result:** Incident ownership is transferred for emergency engineering response.

---

## Notes

- This issue is tied to script execution context differences between GPO logon scripts (user context) and Intune scripts (SYSTEM by default).
- `GroupPolicy` Event ID `1500` success is a strong signal that DC, DNS, and Kerberos are not the primary fault domain.
- If only one user fails while others pass, treat it as a user/session issue first (stale token, profile issue, or existing incorrect persistent drive mapping).
- If the script continues to run in SYSTEM context after this change, validate assignment targeting and policy check-in status before changing script logic.
- Related incident and analysis records:
  - `RCA-finance-shared-drive-failure-20260806.md`
  - `shared-drive-failure-ranked-hypotheses-20260806.md`
  - `finance-shared-drive-incident-communications-20260806.md`
  - `finance-shared-drive-closure-note-20260806.md`
  - `KER-finance-shared-drive-intune-system-context-20260806.md`