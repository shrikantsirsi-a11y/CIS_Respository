# Incident Analysis: AVD Black Screen Post-Login (POOL-FIN-01)

## Incident Snapshot
- **Logged:** 2024-03-15 07:18
- **Reported by:** Maria Lopez, Finance (ext 4421)
- **Symptom:** Black screen after login; some sessions recover in ~30 seconds, others do not recover without Service Desk intervention.
- **Affected pool:** POOL-FIN-01 (Finance)
- **Unaffected pool:** POOL-FIN-02 (IT)
- **Start time:** First reports around 07:00 today
- **Scope:** Multiple Finance users, approximately 40% of POOL-FIN-01
- **Recent change:** Overnight image update to POOL-FIN-01 at 02:00; POOL-FIN-02 was not updated

## Summary
A partial outage is affecting user logins in POOL-FIN-01 with black-screen behavior immediately after session sign-in. The timeline and pool isolation strongly indicate a regression introduced by the 02:00 image update wave for POOL-FIN-01.

## Impact
- **Who:** Finance users assigned to POOL-FIN-01
- **How many:** ~40% of users in the pool (material subset)
- **Business urgency:** High during business start-of-day due to blocked desktop access for Finance operations

## Known Facts
- Symptom occurs only after AVD login and is not user-specific.
- Duration is variable: some sessions recover after ~30 seconds; others stall indefinitely.
- Issue started this morning and was not present yesterday.
- POOL-FIN-02 users (IT) are unaffected.
- POOL-FIN-02 did not receive the overnight image change.

## Working Hypothesis
**Most likely cause:** A bad image change or startup component in the new POOL-FIN-01 image is causing delayed or failed shell initialization (e.g., `explorer.exe` launch path, FSLogix profile attach timing, GPO logon script delay, graphics/AVD agent mismatch, or login-time security tooling contention).

Why this is highest probability:
1. Strong temporal correlation with the 02:00 image update.
2. Clear blast-radius boundary at the host-pool level.
3. Mixed behavior (slow recovery vs no recovery) is consistent with race conditions or resource contention introduced by a new image component.

## Missing Information to Gather (Immediate)
1. Host-level failure distribution: which session hosts in POOL-FIN-01 are over-represented in failures.
2. Build delta: exact image version/package changes between yesterday and current image.
3. AVD diagnostics for affected sign-ins (connection diagnostics, sign-in duration phases).
4. FSLogix profile container health and attach latency at incident time.
5. Logon script and GPO processing durations.
6. GPU/driver and AVD agent versions on failing vs non-failing hosts.
7. Resource pressure at 07:00-08:00 (CPU, RAM, disk queue) by host.

## Immediate Triage Actions (0-30 min)
1. **Containment:** Drain new logins from the worst-affected hosts in POOL-FIN-01.
2. **Service restoration path:** Redirect impacted users to known-good hosts/image if available.
3. **Rollback decision gate:** If failure rate remains above threshold (for example >10-15% after containment), begin rollback to previous stable image for POOL-FIN-01.
4. **Comms:** Issue internal advisory to Finance with workaround ETA and active mitigation status.

## Validation Checks (What to Test First)
1. Compare one failing and one healthy POOL-FIN-01 host:
   - Event Viewer: User Profile Service, Shell-Core, Winlogon, AppReadiness, GroupPolicy, FSLogix.
   - AVD agent health and heartbeat.
   - Startup app/service differences and boot/logon duration counters.
2. Launch test sessions against:
   - Current updated image host.
   - Previous image host (or restored golden image).
   Confirm black-screen reproduction only on updated image path.
3. Confirm whether manually restarting `explorer.exe` restores desktop for a stuck session; if yes, prioritize shell-init path investigation.

## Likely Category
**AVD Platform / Image Regression / Logon Initialization**

## Preliminary Severity Recommendation
- **Suggested severity:** SEV-2 (major degradation across a business unit, partial access)
- Escalate to **SEV-1** if impact crosses business-critical threshold or rollback cannot restore access quickly.

## Recommended Remediation Plan
1. Execute controlled rollback of POOL-FIN-01 to last known good image.
2. Keep POOL-FIN-02 unchanged as control baseline.
3. After stabilization, run change-delta RCA:
   - Compare app/driver/security agent updates introduced at 02:00.
   - Validate FSLogix and AVD agent compatibility matrix.
   - Re-test image in pre-prod with synthetic logon load before re-release.
4. Implement phased deployment policy for future image waves (canary subset before full pool rollout).

## User-Facing Interim Workaround
- Retry sign-in once.
- If black screen persists beyond 60 seconds, disconnect and reconnect to force placement on alternate host.
- Service Desk to prioritize reassignment to known-good hosts while rollback is in progress.

## Executive One-Liner
A likely image-related regression introduced at 02:00 is causing partial login failures in Finance AVD pool POOL-FIN-01; containment and rollback to the prior image are the fastest paths to restore service.
