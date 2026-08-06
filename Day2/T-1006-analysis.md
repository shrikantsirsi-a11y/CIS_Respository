# T-1006 Analysis: 'Everything Is Slow' — User Upgraded to Win11 Two Days Ago

## Summary
User reports general system-wide slowness two days after upgrading to Windows 11.

## Impact
- **Who:** One reporting user.
- **How many:** 1 device confirmed; unknown if others who upgraded around the same time are affected (to-verify).
- **Business urgency:** Medium—productivity impacted but device is usable.

## Known Facts
- Device was upgraded to Windows 11 two days prior to the report.
- User describes the issue broadly as "everything is slow" (no specific app/process named yet).

## Missing Information to Gather
1. Is the slowness constant, or does it happen at specific times (startup, opening apps, waking from sleep)?
2. Which specific applications or actions feel slow (all apps, specific apps, file access, boot time)?
3. What does Task Manager show for CPU, Memory, Disk, and Network usage during the slow periods?
4. Has any post-upgrade driver, application, or antivirus/security update occurred? (to-verify)
5. Is the device meeting minimum hardware requirements for Windows 11 (RAM, storage type, TPM)? (to-verify)
6. How much free disk space is available?
7. Were all drivers (especially chipset, storage, graphics) updated/compatible after the upgrade? (to-verify)
8. Is background app/indexing activity (e.g., Windows Search indexing, post-upgrade optimization) still running given it's only been two days?
9. Did the user notice slowness immediately after upgrade, or did it develop over the two days?

## Likely Category
**OS Upgrade – Performance / Post-Migration Optimization**

## First Diagnostic Step
1. Open Task Manager during a period of reported slowness and record top CPU, Memory, and Disk consumers.
2. Check free disk space and confirm the device meets Windows 11 hardware requirements.
3. Check Windows Update for any pending driver or firmware updates not yet applied since the upgrade.
4. Note whether background processes (e.g., search indexing, delivery optimization) are still completing post-upgrade, as this is common in the first few days. (to-verify)

---

**Next Steps:** Isolate specific slow actions and Task Manager evidence before deciding if this is a temporary post-upgrade indexing issue or a driver/compatibility problem.
