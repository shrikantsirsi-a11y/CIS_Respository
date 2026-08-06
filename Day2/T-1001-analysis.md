# T-1001 Analysis: New Win11 Laptop, BitLocker Recovery Key Prompt at Boot

## Summary
New Win11 laptop repeatedly prompts for BitLocker recovery key on every boot, preventing normal startup.

## Impact
- **Who:** Single user (device owner of T-1001).
- **How many:** 1 laptop affected.
- **Business urgency:** High—device cannot boot without manual intervention; user is blocked from work.

## Known Facts
- Device is new (recently provisioned).
- Windows 11 OS.
- BitLocker is enabled.
- Recovery key prompt occurs at every boot (consistent reproduction).
- No indication of user error, data corruption, or hardware failure in ticket.

## Missing Information to Gather
1. When did the laptop first arrive/boot? (Hours/days ago?)
2. Has the device successfully booted since first power-on?
3. Was BitLocker enabled during initial setup/deployment, or did the user enable it?
4. Has the device been rebooted before, or is this the first boot?
5. Is a recovery key available (provided by IT, in the portal, or written down)?
6. Was the device disconnected from network or domain during initial setup?
7. Are there any BIOS/firmware error messages or warnings before the BitLocker prompt?
8. Is the TPM (Trusted Platform Module) detected and enabled in BIOS? (to-verify)
9. Has the device been reset, or is the OS installation clean/imaged?
10. What deployment method was used (Intune, SCCM, manual install, OEM image)? (to-verify)

## Likely Category
**BitLocker / Encryption / Boot Issue** — escalate to Hardware/Deployment team if TPM or provisioning is at fault; escalate to Security if the recovery key is unavailable.

## First Diagnostic Step
1. Ask the user to retrieve and provide the BitLocker recovery key through an approved secure channel (never via public AI or unsecured chat).
2. Have the user enter the recovery key at boot to unlock the device.
3. Once booted, check **Settings → Privacy & Security → BitLocker** for status, recovery options, and whether the key is synced to the organizational vault or Microsoft account.
4. Check Device Manager for the TPM entry; if missing or showing errors, flag for hardware diagnostics. (to-verify)
5. Note the BIOS/firmware version and whether it has been patched/updated since provisioning.
6. If BitLocker status shows "Suspended" or an error state, document and escalate to the deployment/imaging team.

---

**Next Steps:** Gather the missing information above before escalating to Hardware or Security as needed.
