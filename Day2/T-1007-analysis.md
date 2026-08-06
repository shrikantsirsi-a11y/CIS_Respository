# T-1007 Analysis: OneDrive Stuck 'Processing Changes' Since Migration; Files Missing Locally

## Summary
OneDrive has been stuck on "processing changes" since a recent migration, and some files are missing locally.

## Impact
- **Who:** One reporting user; scope of missing files and whether others migrated at the same time are affected is unknown (to-verify).
- **How many:** 1 user confirmed.
- **Business urgency:** High—missing files may block active work and risk data loss/access concerns.

## Known Facts
- A migration has occurred (type/scope not specified — e.g., tenant-to-tenant, account re-provisioning, PC replacement). (to-verify)
- OneDrive sync status is stuck showing "processing changes."
- Some files that should be present locally are missing.

## Missing Information to Gather
1. What kind of migration occurred (OneDrive/tenant migration, new device, account re-mapping)? (to-verify)
2. When did the migration complete, and when did syncing stop progressing?
3. Are the missing files visible in the OneDrive web portal (i.e., present in the cloud but not synced locally)?
4. Is OneDrive showing any specific sync error icons or messages (not codes—just describe what's shown)?
5. How many files/folders appear affected, and are they in a specific folder or the whole OneDrive?
6. Is the user connected to a stable network with sufficient bandwidth during sync?
7. Is there sufficient local disk space for the files to sync down?
8. Has OneDrive been signed out/reset, or has "processing changes" simply not progressed over time?
9. Are Known Folder Move settings (Desktop/Documents/Pictures) involved, and were they part of the migration? (to-verify)

## Likely Category
**OneDrive / Cloud Storage – Sync Failure (Post-Migration)**

## First Diagnostic Step
1. Check the OneDrive web portal to confirm whether the missing files exist in the cloud (data-loss vs. sync-only issue).
2. Check the OneDrive sync icon/status pane on the device for specific error descriptions or paused/stuck indicators.
3. Confirm available local disk space and network connectivity.
4. If files exist in the cloud but not locally, this points to a sync/client issue rather than data loss — escalate accordingly rather than attempting a reset without confirming cloud copy exists.

---

**Next Steps:** Confirm cloud-side file presence first to rule out data loss before any resync or profile reset action.
