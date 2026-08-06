# AVD Incident Analysis and Hypothesis (Timing-Weighted)

## Scope Facts Used
- Symptom: black screen post-login; clears after ~30s for some users, persists for others.
- Who: ~40% of users on POOL-FIN-01; POOL-FIN-02 completely unaffected.
- Since: ~07:00 this morning.
- Change: overnight image update to POOL-FIN-01 at 02:00; POOL-FIN-02 was not updated.

## Control-Group Inference
POOL-FIN-02 acts as a clean control group. It shares platform context but had no image update and no symptoms. That strongly favors update-scoped causes in POOL-FIN-01 over tenant-wide or shared infrastructure failures.

## Surviving Hypothesis After Evidence Elimination
**Graphics stack regression in the updated POOL-FIN-01 image** (DWM crash in Intel graphics module `igdumd64.dll`).

Why this survives:
- Affected host repeatedly logs `Application Error` Event 1000 for `dwm.exe` faulting in `igdumd64.dll` during user sign-in attempts.
- DWM exits with error (`Desktop Window Manager` Event 9009) immediately after logon success (`TerminalServices-LocalSessionManager` Event 21), followed by disconnect (`Event 40`).
- Unaffected POOL-FIN-02 host shows successful DWM start (`Event 9011`) and no application errors in the same window.

This points to an image-introduced graphics driver/regression path rather than FSLogix, GPO/logon-script, or generic shell-init delay.

## Re-Ranked Top 5 Causes (Most Probable First)

### 1) Image regression in shell/logon initialization
- Why this fits: Direct alignment with timing and blast radius. Only the updated pool shows symptoms after users begin logging in.
- Fastest single check: Compare shell/logon events on one failing POOL-FIN-01 host vs one healthy POOL-FIN-02 host; confirm delayed/missing `explorer.exe` start or AppReadiness stalls.

### 2) FSLogix profile attach regression triggered by updated image
- Why this fits: Black screen after sign-in is consistent with profile container attach delays/timeouts; partial impact matches host/profile timing variance.
- Fastest single check: Review FSLogix logs during a failing login on POOL-FIN-01 for retries/timeouts; validate absence on POOL-FIN-02.

### 3) AVD agent/service mismatch on a subset of updated hosts
- Why this fits: ~40% impact suggests not all hosts are bad; users landing on specific hosts may fail while others succeed.
- Fastest single check: Correlate incidents by session host; verify failing hosts share an agent/service/version state absent on healthy hosts.

### 4) Startup security component or logon script delay introduced in image
- Why this fits: Can produce variable black-screen durations and occasional hangs; still consistent with update-only pool impact.
- Fastest single check: Inspect GroupPolicy operational events for one failing session and identify any blocking extension/script with abnormal runtime.

### 5) Graphics stack regression in updated image (driver/codec/acceleration)
- Why this fits: Symptom-compatible and update-scoped, but less aligned with the partial/race-like pattern than shell/profile causes.
- Fastest single check: Run a controlled test on an affected host with acceleration/driver fallback and re-test login behavior immediately.

## Positioning Statement
This ranking intentionally weights the timing clue and control-pool evidence heavily. It narrows to update-induced causes without prematurely committing to a single root cause before checks are complete.

## Resolution Steps (Detailed Runbook)

### Phase 1: Stabilize Service Immediately
1. Place impacted POOL-FIN-01 session hosts into drain mode (no new sessions).
2. Reassign active affected users to known-good hosts if available.
3. If user impact remains high, shift user assignments temporarily to unaffected capacity while remediation proceeds.
4. Send user advisory: known issue, reconnect guidance, and estimated next update time.

### Phase 2: Confirm and Isolate the Fault Domain
1. On one failing host (for example SHFIN-01-A), confirm repeating pattern:
	- `Event 21` (logon succeeded)
	- `Event 1000` (`dwm.exe` faulting module `igdumd64.dll`)
	- `Event 9009` (DWM exit)
	- `Event 40` (disconnect)
2. On one healthy POOL-FIN-02 host, confirm control pattern:
	- `Event 21` followed by `Event 9011` (DWM started successfully)
	- No `Event 1000` for `dwm.exe` in same window.
3. Record host/image/driver versions for incident record and RCA.

### Phase 3: Remediate the Graphics Regression
1. Roll back POOL-FIN-01 image to the last known-good pre-update image (same lineage as POOL-FIN-02 if validated).
2. Reimage or replace affected session hosts from the rolled-back image.
3. In parallel on a test host, apply one of these controlled mitigations and validate:
	- Roll back Intel display driver from `31.0.101.4146` to prior known-good version.
	- Pin/disable problematic driver auto-update path in image pipeline until validated.
	- Apply vendor hotfix if available and tested.
4. Restart host after driver change and validate 5-10 consecutive test logons.

### Phase 4: Validate Recovery Before Full Reopen
1. Validate on remediated hosts:
	- No new `Event 1000` (`dwm.exe`/`igdumd64.dll`) during logon tests.
	- Presence of normal DWM startup (`Event 9011` or equivalent healthy startup entries).
	- No immediate `Event 40` disconnect after `Event 21` logon success.
2. Reopen hosts gradually (canary batch first, then wider pool) and monitor for 30-60 minutes.
3. Exit incident only after error rate remains at baseline and user complaints stop.

### Phase 5: Prevent Recurrence
1. Add pre-production validation gate for graphics stack changes in AVD images.
2. Enforce canary deployment (small subset of POOL-FIN-01) before full wave rollout.
3. Add automated post-deploy health check:
	- Detect spike in `Event 1000` for `dwm.exe`.
	- Detect increased session disconnects after successful logon.
4. Update rollback playbook with explicit trigger thresholds and owner/on-call roles.

## Evidence Update: Event Details (2024-03-15 07:00-07:30)

### Affected Host: SHFIN-01-A (POOL-FIN-01)
- `07:02:10` `TerminalServices-LocalSessionManager` `Event 21`: Session logon succeeded (`FINBRIDGE\\mlopez`, Session 3).
- `07:02:14` `Kernel-General` `Event 1`: Host boot time `02:03:11` (post-image-update restart context).
- `07:02:16` `Application Error` `Event 1000`: `dwm.exe` faulting module `igdumd64.dll` (`0xc0000005`).
- `07:02:17` `TerminalServices-LocalSessionManager` `Event 40`: Session disconnected (Session 3).
- `07:02:18` `Desktop Window Manager` `Event 9009`: DWM exited with error code `0x40010004`.
- `07:02:44` `TerminalServices-LocalSessionManager` `Event 21`: Reconnect logon succeeded (Session 3).
- `07:02:46` `Application Error` `Event 1000`: repeated `dwm.exe` / `igdumd64.dll` crash.
- `07:02:47` `TerminalServices-LocalSessionManager` `Event 40`: Session disconnected again.
- `07:03:01` `Desktop Window Manager` `Event 9009`: DWM exited with error again.
- `07:03:10` `TerminalServices-LocalSessionManager` `Event 21`: second reconnect logon succeeded (Session 4).
- `07:08:22` `TerminalServices-LocalSessionManager` `Event 21`: Session logon succeeded (`FINBRIDGE\\akapoor`, Session 5).
- `07:08:24` `Application Error` `Event 1000`: same `dwm.exe` / `igdumd64.dll` crash pattern.

### Control Host: SHFIN-02-A (POOL-FIN-02, Unaffected)
- Image: `10.0.22621.2861-build-20240313` (pre-update).
- `07:01:44` `TerminalServices-LocalSessionManager` `Event 21`: Session logon succeeded.
- `07:01:46` `Desktop Window Manager` `Event 9011`: DWM started successfully.
- No `Application Error` `Event 1000` in the same window.

## Survived Hypothesis (Post-Elimination)
The surviving hypothesis is a **graphics stack regression introduced by the POOL-FIN-01 image update**, specifically repeated `dwm.exe` failures in Intel graphics module `igdumd64.dll` during post-login rendering.

Why this survived elimination:
- The affected host shows repeated `Event 1000` (`dwm.exe` -> `igdumd64.dll`) followed by DWM exit and session disconnect.
- The unaffected, non-updated control pool shows normal DWM startup and no matching crash signature.
- This evidence directly fits update-scoped impact and the black-screen symptom behavior.

## Resolution Update (Detailed)

### 1) Immediate Service Stabilization
1. Put affected POOL-FIN-01 hosts in drain mode.
2. Redirect impacted users to known-good capacity.
3. Maintain user communications and workaround guidance (reconnect if black screen exceeds 60 seconds).

### 2) Confirm Signature on Live Hosts
1. Validate the failure chain on impacted hosts: `Event 21` -> `Event 1000` (`dwm.exe`/`igdumd64.dll`) -> `Event 9009` -> `Event 40`.
2. Validate healthy chain on control hosts: `Event 21` -> successful DWM start (`Event 9011`) with no app crash.

### 3) Corrective Action (Rollback-First)
1. Roll back POOL-FIN-01 to last known-good image.
2. Recreate/reimage affected hosts from known-good baseline.
3. In test lane, roll back Intel display driver from `31.0.101.4146` to last known-good version or apply vetted vendor fix.
4. Reboot test host and run repeated logon validation.

### 4) Recovery Validation and Reopen
1. Confirm no new `Event 1000` for `dwm.exe` during controlled logons.
2. Confirm no immediate post-logon disconnects.
3. Reopen hosts in canary batches, then scale out.
4. Monitor 30-60 minutes for stability before incident closure.

### 5) Recurrence Prevention
1. Add explicit image release gate for graphics driver/stack changes.
2. Enforce canary rollout before full pool deployment.
3. Implement automated alerting for DWM crash spikes and post-logon disconnect spikes.
4. Update rollback criteria and ownership in operations runbook.
