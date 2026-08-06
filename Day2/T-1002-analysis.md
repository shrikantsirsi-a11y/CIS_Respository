# T-1002 Analysis: Finance User Cannot Open Shared Mailbox After Migration

## Summary
Finance user is unable to open a shared mailbox following a recent mailbox migration.

## Impact
- **Who:** One named Finance user; potentially other users sharing the same mailbox (to-verify).
- **How many:** At least 1 user confirmed; scope of shared mailbox users unknown (to-verify).
- **Business urgency:** Medium-High—Finance function may depend on shared mailbox for time-sensitive correspondence (e.g., invoicing, approvals).

## Known Facts
- A migration has recently taken place (type/scope not specified).
- User cannot open the shared mailbox post-migration.
- User is in the Finance team.

## Missing Information to Gather
1. What was migrated (mailbox platform, tenant, on-prem to cloud, server move)? (to-verify)
2. When did the migration complete, and when did the issue start?
3. Does the user still have access to their own primary mailbox?
4. How does the user normally access the shared mailbox (Outlook desktop, OWA, mobile, added as additional mailbox, or full access permission)?
5. Is the error a permissions error, mailbox not found, or does Outlook simply not load/show it?
6. Have shared mailbox permissions been reassigned or verified since migration?
7. Are other users of the same shared mailbox affected, or just this one user?
8. Is the user's Outlook profile up to date, or does it need to be recreated post-migration?
9. Is the user on Outlook desktop client, new Outlook, or OWA? (to-verify)

## Likely Category
**Exchange/Email – Mailbox Access & Permissions (Post-Migration)**

## First Diagnostic Step
1. Confirm the user's own mailbox works normally (login, send/receive).
2. Check whether the shared mailbox still shows in Outlook's folder list; if missing, check if it needs to be re-added.
3. Verify (via approved admin tooling, not public AI) that the user's permissions on the shared mailbox migrated correctly.
4. If permissions are intact but access still fails, have the user recreate their Outlook profile or clear the cached Outlook data (to-verify against DWP standard procedure).

---

**Next Steps:** Confirm migration scope and permissions state before further action.
