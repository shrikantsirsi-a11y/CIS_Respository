# T-1005 Analysis: Teams Audio Dead on Three Machines in the Same Meeting Room

## Summary
Teams audio is not working on three machines located in the same meeting room.

## Impact
- **Who:** Users of the affected meeting room (number of individual users unknown, but 3 machines affected).
- **How many:** 3 devices confirmed.
- **Business urgency:** Medium-High—meeting room unusable for calls, likely affecting multiple meetings/teams relying on that room.

## Known Facts
- Issue is isolated to Microsoft Teams audio.
- Three separate machines are affected.
- All affected machines are in the same physical meeting room.

## Missing Information to Gather
1. Are these dedicated Teams Room / meeting room system devices, or personal laptops used in that room?
2. Is the issue no audio output, no microphone input, or both?
3. Did this start suddenly, or after a specific change (room AV update, device replacement, cabling change)?
4. Are all three machines using the same audio hardware (e.g., shared room speakerphone/soundbar) or independent peripherals?
5. Does audio work in other applications (e.g., media player, system sound test) on these machines?
6. Is the issue specific to Teams only, or all calling/conferencing apps?
7. Has anything changed in the room recently (new equipment, firmware update, cabling, network change)?
8. Do these machines work fine with Teams audio in a different room/location?
9. Is there a shared USB/Bluetooth conferencing device involved, and is it recognized by Windows? (to-verify)

## Likely Category
**Collaboration/AV – Teams Audio Hardware or Room Configuration**

## First Diagnostic Step
1. Check Windows Sound settings on one affected machine to confirm the correct audio input/output device is selected and recognized.
2. Test system-level audio (non-Teams) to isolate whether this is a Teams-specific issue or a hardware/driver issue.
3. Inspect physical connections and shared room AV equipment (cabling, power, USB/Bluetooth pairing) for the room's conferencing device.
4. Confirm whether all three machines share the same room hardware, which would point to a room-AV fault rather than three separate device faults.

---

**Next Steps:** Determine whether the fault is shared room hardware or the machines' individual Teams configuration before dispatching for AV hardware inspection.
