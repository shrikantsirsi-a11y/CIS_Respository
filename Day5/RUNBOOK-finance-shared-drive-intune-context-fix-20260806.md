## Version Header

**Title:** Runbook — Restore Finance Shared Drive Mapping (Intune Script Context Fix)  
**Version:** 1.0  
**Date:** 07/08/2026  
**Author:** Srikantha Satyanarayan  
**Reviewed:** self  
**Status:** draft  
**Change:** initial version from RCA

---

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
   **Expected result:** The left navigation menu shows `Home`, `Dashboard`, `Devices`, and `Users`.

3. Select **Devices** in the left navigation.  
   **Expected result:** The page header shows **Devices | Overview**.

4. Select **Scripts and remediations** under **Policy**.  
   **Expected result:** The page header shows **Scripts and remediations**.

5. Select the **Platform scripts** tab.  
   **Expected result:** A table of Windows scripts is displayed with a **Name** column.

6. Select `Map-FinBridgeDrives.ps1` from the **Name** column.  
   **Expected result:** The script details page opens and shows the selected script name.

7. Select **Properties** in the script details page.  
   **Expected result:** The **Script settings** section is visible.

8. Select **Edit** in the **Script settings** section. **[ELEVATED]**  
   **Expected result:** The setting fields become editable.

9. Set **Run this script using the logged-on credentials** to **Yes**. **[ELEVATED]**  
   **Expected result:** The field shows **Yes**.

10. Select **Review + save**. **[ELEVATED]**  
    **Expected result:** The review pane shows **Run this script using the logged-on credentials: Yes**.

11. Select **Save**. **[ELEVATED]**  
    **Expected result:** A green portal notification states the update completed successfully.

12. Select **Devices > All devices** in the left navigation.  
    **Expected result:** The page header shows **All devices**.

13. Enter `DESKTOP-FB041` in the **Search** box.  
    **Expected result:** A row for `DESKTOP-FB041` appears in the results table.

14. Select the `DESKTOP-FB041` device row.  
    **Expected result:** The device details page opens and shows **Managed by: Intune**.

15. Select **Sync**. **[ELEVATED]**  
    **Expected result:** A green portal notification states the sync request was sent.

16. Ask the user on `DESKTOP-FB041` to sign out.  
    **Expected result:** The Windows sign-in screen is displayed.

17. Ask the user on `DESKTOP-FB041` to sign in again.  
    **Expected result:** The user reaches the desktop without sign-in errors.

18. Open File Explorer on `DESKTOP-FB041`.  
    **Expected result:** File Explorer opens without error.

19. Select drive `S:` in **This PC**.  
    **Expected result:** The address bar shows `\\finbridge-fs01\Finance` and folders/files are listed.

---

## Verification

1. Open Notepad as administrator on `DESKTOP-FB041`. **[ELEVATED]**  
   **Expected result:** Notepad opens with admin rights (UAC prompt accepted).

2. Open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` from Notepad.  
   **Expected result:** The log file opens and recent entries are visible.

3. Press `Ctrl+F` and search the log for `Map-FinBridgeDrives.ps1 completed successfully`.  
   **Expected result:** A hit is found with `Exit code: 0` after the sync timestamp.

4. Open Event Viewer on `DESKTOP-FB041`.  
   **Expected result:** Event Viewer opens with the left navigation tree visible.

5. Select **Event Viewer (Local) > Windows Logs > System**.  
   **Expected result:** System events are listed in the center pane.

6. Select **Filter Current Log...** in the right **Actions** pane.  
   **Expected result:** The filter dialog opens.

7. Enter `98` in **<All Event IDs>** and select **OK**.  
   **Expected result:** Only Event ID `98` entries are displayed.

8. Confirm there are no Event ID `98` entries with a **Date and Time** after the remediation timestamp.  
   **Expected result:** No post-fix Event 98 records are present.

9. Open File Explorer and select `S:` as the affected Finance user.  
   **Expected result:** The user can open at least one known subfolder and one file under `\\finbridge-fs01\Finance`.

10. Check the service desk queue filter for `Finance` + `S:` + `cannot access` after rollout.  
    **Expected result:** No new matching tickets are created for at least 30 minutes.

Only close the incident after all verification steps pass.

---

## Rollback

Use this rollback only if the procedure causes broader impact (for example, login script errors, incorrect mappings, or expanded user impact).

Time target: complete Steps 1 to 8 within 3 minutes.

1. Open `https://intune.microsoft.com` and sign in.  
   **Expected result:** The left navigation menu is visible.

2. Select **Devices > Scripts and remediations > Platform scripts**.  
   **Expected result:** The Platform scripts table is visible.

3. Select `Map-FinBridgeDrives.ps1` in the scripts table.  
   **Expected result:** The script details page opens.

4. Select **Properties** on the script details page.  
   **Expected result:** The **Script settings** section is visible.

5. Select **Edit** in **Script settings**. **[ELEVATED]**  
   **Expected result:** The setting fields become editable.

6. Set **Run this script using the logged-on credentials** to **No**. **[ELEVATED]**  
   **Expected result:** The value displays **No**.

7. Select **Review + save**. **[ELEVATED]**  
   **Expected result:** The review pane shows **Run this script using the logged-on credentials: No**.

8. Select **Save**. **[ELEVATED]**  
   **Expected result:** A green notification confirms the script update completed successfully.

9. Select **Devices > All devices** in the left navigation.  
   **Expected result:** The **All devices** page opens.

10. Enter `DESKTOP-FB041` in the device search box.  
    **Expected result:** A row for `DESKTOP-FB041` is displayed.

11. Select the `DESKTOP-FB041` device row.  
    **Expected result:** The device details page opens.

12. Select **Sync** on the device page. **[ELEVATED]**  
    **Expected result:** A green notification states the sync request was sent.

13. Open Command Prompt in the affected user session on `DESKTOP-FB041`.  
    **Expected result:** A command window opens in the user context.

14. Run `net use S: /delete /y`.  
    **Expected result:** Output shows `S: was deleted successfully` or `The network connection could not be found`.

15. Run `net use S: \\finbridge-fs01\Finance /persistent:yes`.  
    **Expected result:** Output shows `The command completed successfully.`

16. Open File Explorer and select `This PC > S:`.  
    **Expected result:** The path `\\finbridge-fs01\Finance` opens and folder contents load.

17. Ask the user to sign out.  
    **Expected result:** The Windows sign-in screen is displayed.

18. Ask the user to sign in.  
    **Expected result:** The user reaches desktop and `S:` is still present.

19. Open a P1 escalation ticket to Desktop Engineering if more than 5 Finance users still cannot access `S:` after Step 18.  
    **Expected result:** Ownership transfers to engineering with rollback timestamps and affected device list attached.

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