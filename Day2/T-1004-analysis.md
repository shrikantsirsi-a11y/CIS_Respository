# T-1004 Analysis: Company App Fails to Install from Company Portal, Error 0x87D1041C

## Summary
Company app installation fails via Company Portal with error code 0x87D1041C.

## Impact
- **Who:** One reporting user; unknown if error affects others deploying the same app (to-verify).
- **How many:** At least 1 user confirmed; broader scope unknown.
- **Business urgency:** Medium—user cannot access a required application, but no indication of full device or service outage.

## Known Facts
- Deployment method is Company Portal (Intune-managed, typically).
- Error code reported: 0x87D1041C (as provided in the ticket).
- The failure occurs specifically during app installation.

## Missing Information to Gather
1. Which app is failing to install (name, version)?
2. Is this a Win32 app, MSI, or Microsoft Store app deployment? (to-verify)
3. Does the error occur immediately, partway through download, or during installation?
4. Is the device compliant and checking in successfully with Intune/MDM? (to-verify)
5. Has this app installed successfully on this device before, or is this a first-time install?
6. Is the issue isolated to one device, or reproducible on other devices/users targeted by the same app assignment?
7. Is the device connected to a stable network with access to required endpoints during install?
8. Has the user tried a manual retry or device restart?
9. Is there sufficient free disk space on the device? (to-verify)

## Likely Category
**Application Deployment – Intune/Company Portal Install Failure**

## First Diagnostic Step
1. Confirm the exact app name and check its assignment/deployment status in the endpoint management console (not public AI) for this device.
2. Verify device compliance and last check-in time with Intune.
3. Check available disk space and network connectivity on the affected device.
4. Cross-reference error 0x87D1041C against internal/approved Microsoft documentation for its category (e.g., download vs. install vs. requirement failure) before further action. (to-verify)

---

**Next Steps:** Confirm scope (single device vs. broader) and check deployment/compliance status before escalating to the Application Packaging team.
