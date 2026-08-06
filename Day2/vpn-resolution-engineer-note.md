Root cause: Win11 upgrade removed legacy VPN client; Intune did not trigger re-deployment of the new client due to a detection-rule gap.

Exact action taken:
1. Manually removed stale VPN registry entries under HKLM\SOFTWARE<vendor>.
2. Force-triggered Intune sync.
3. New VPN client deployed.
4. Split-tunnel config applied.

Verification:
1. Connectivity confirmed to all internal subnets.
2. No data loss.

Preventive action needed:
1. Remediate detection-rule gap so Intune reliably re-deploys the new VPN client after Win11 upgrade/removal scenarios.
