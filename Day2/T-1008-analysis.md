# T-1008 Analysis: VPN Connects But No Internal Resources Reachable After Win11 Upgrade

## Summary
VPN connects successfully but internal resources are unreachable following a Windows 11 upgrade.

## Impact
- **Who:** One reporting user; unknown if other recently upgraded users are affected (to-verify).
- **How many:** 1 device confirmed.
- **Business urgency:** High—user has no access to internal resources needed for work despite an apparently successful VPN connection.

## Known Facts
- Device was recently upgraded to Windows 11.
- VPN client reports a successful connection.
- Internal resources (servers, shares, intranet, etc.) are not reachable despite the connection.

## Missing Information to Gather
1. Which internal resources are unreachable (specific servers, shares, intranet sites, all of them)?
2. Does the VPN client show a connected state with an assigned IP address? (to-verify)
3. Can the user reach any internal resource at all (e.g., ping, browse, map a drive), or is it a complete failure?
4. Did the VPN client itself get reinstalled/updated as part of the Win11 upgrade, or is it the same version as before?
5. Are there any local firewall or network profile changes since the upgrade (e.g., network set to "Public" instead of "Private/Domain")? (to-verify)
6. Does DNS resolution work for internal hostnames while connected? (to-verify)
7. Is split-tunnel or full-tunnel VPN configured, and did that behavior change post-upgrade? (to-verify)
8. Did this work correctly before the Windows 11 upgrade on this same device?
9. Are other apps/services (e.g., email, Teams) also affected, or only specific internal network resources?

## Likely Category
**VPN / Network Connectivity – Post-OS-Upgrade Configuration**

## First Diagnostic Step
1. Confirm VPN connection details (assigned internal IP, connected duration) to verify a genuine tunnel is established.
2. Check the Windows network profile (Public vs. Private/Domain) for the VPN adapter, as this commonly resets after an OS upgrade and can block resource access. (to-verify)
3. Test DNS resolution and basic reachability (e.g., ping) to a known internal resource while connected.
4. Confirm VPN client version/compatibility with Windows 11 and whether a reinstall or update is required. (to-verify)

---

**Next Steps:** Verify network profile and DNS resolution first, as these are common causes of "connected but unreachable" VPN issues after an OS upgrade.
