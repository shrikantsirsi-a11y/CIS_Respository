# T-1003 Analysis: AVD Session Disconnects After ~10 Minutes, Then Reconnects

## Summary
Azure Virtual Desktop (AVD) session disconnects approximately every 10 minutes and then automatically reconnects.

## Impact
- **Who:** One reporting user; unknown whether others on the same AVD host pool are affected (to-verify).
- **How many:** At least 1 user confirmed; scope unknown.
- **Business urgency:** Medium-High—repeated disconnection disrupts productivity and may cause unsaved work loss.

## Known Facts
- Platform is Azure Virtual Desktop (AVD).
- Disconnection occurs at a consistent ~10 minute interval.
- Session reconnects automatically afterward (not a full outage).

## Missing Information to Gather
1. Is this happening on a specific AVD host pool, or across multiple pools? (to-verify)
2. Is the user on a specific network (home, office, VPN) each time this occurs?
3. Does the disconnect correlate with a specific idle timeout, network re-authentication, or Conditional Access policy? (to-verify)
4. Is the user using the AVD desktop client, web client, or mobile client?
5. Are other users on the same host pool or session host reporting the same pattern?
6. Does the issue happen at exactly 10 minutes consistently, or does it vary?
7. Is there a specific application running when the disconnect occurs?
8. What is the user's network connection type and stability (Wi-Fi, wired, VPN, mobile hotspot)?
9. Has this started recently, or has it always happened? What changed, if anything?

## Likely Category
**AVD / Remote Desktop – Session Connectivity**

## First Diagnostic Step
1. Reproduce the issue with the user and note the exact time-to-disconnect and any on-screen message during disconnect/reconnect.
2. Check the user's local network stability (Wi-Fi signal, VPN status) during the session to rule out client-side network drops.
3. Confirm whether other users on the same host pool/session host are experiencing similar disconnects (to-verify via monitoring tooling, not public AI).
4. Review AVD client logs/event viewer on the local device for reconnect/disconnect events around the 10-minute mark (to-verify against approved diagnostic procedure).

---

**Next Steps:** Determine if the pattern is host-pool-wide or isolated to this user/device before escalating to the AVD platform team.
