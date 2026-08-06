# Root Cause Analysis (RCA): Account Lockout — jsmith

## Incident Summary

| Field | Detail |
|---|---|
| **Affected account** | `jsmith` |
| **Affected system** | `DESKTOP-FB001` |
| **Incident window** | 08:02:14 – 08:23:44 (approx. 22 minutes) |
| **Impact** | User unable to log on to workstation; account locked out for ~16 minutes until helpdesk intervention |
| **Resolution** | Account re-enabled by `FINBRIDGE\helpdesk-admin`; user successfully logged on afterward |
| **Severity** | Low (single user, single workstation, no evidence of compromise) |

## Event Timeline

| Time | Event ID | Result | Description |
|---|---|---|---|
| 08:02:14 | 4625 | Audit Failure | Failed interactive logon (type 2) — unknown username or bad password |
| 08:04:22 | 4625 | Audit Failure | Second failed interactive logon (type 2) — unknown username or bad password |
| 08:06:01 | 4740 | Audit Failure | Account locked out, triggered from `DESKTOP-FB001` |
| 08:07:45 | 4625 | Audit Failure | Failed unlock attempt (type 7) — account locked out |
| 08:22:10 | 4722 | Audit Success | Account re-enabled by `FINBRIDGE\helpdesk-admin` |
| 08:23:44 | 4624 | Audit Success | Successful interactive logon (type 2) |

## Root Cause Statement

The user (`jsmith`) entered an incorrect password twice in quick succession at their own workstation, tripping the domain account-lockout policy. The account remained locked for ~16 minutes until the user contacted the helpdesk, who manually re-enabled the account. There is no evidence of malicious activity, remote access, or attack from another source — all events originate from the user's own workstation.

## 5 Why Analysis

1. **Why was `jsmith`'s account locked out?**
   Because two consecutive failed logon attempts (4625 at 08:02:14 and 08:04:22) exceeded the domain's bad-password-attempt threshold, triggering an automatic lockout (4740 at 08:06:01).

2. **Why did the logon attempts fail?**
   Because the password entered did not match the account's stored credentials ("Unknown username or bad password"), and both attempts were interactive logons at the same workstation, indicating the user typed the wrong password rather than a system or network fault.

3. **Why did the user enter the wrong password multiple times?**
   Most likely because the user had forgotten a recently changed password, mistyped it, or was using a cached/outdated credential — no corroborating event indicates a system, keyboard, or authentication-service fault.

4. **Why did the lockout last ~16 minutes before resolution?**
   Because the user did not have (or did not use) a self-service password/unlock mechanism, and instead had to contact the helpdesk, wait for a helpdesk admin to become available, and have the account manually re-enabled (4722 at 08:22:10).

5. **Why is there no self-service unlock capability reducing this downtime?**
   Because the organization's current process relies on manual helpdesk intervention for account unlocks rather than an automated self-service password reset/unlock tool, resulting in avoidable user downtime for a low-risk, self-inflicted lockout.

## Contributing Factors

- No self-service password reset (SSPR) or account unlock tool available to end users.
- No indication the user received a warning after the first failed attempt (e.g., "1 attempt remaining before lockout").
- Low lockout threshold (2 failures observed before lockout) combined with no user-facing feedback increases likelihood of accidental lockouts.

## Evidence Supporting Root Cause (Ruling Out Malicious Activity)

- All 4625 events originate from the **same single workstation** (`DESKTOP-FB001`), consistent with the legitimate user's own device, not a remote or distributed source.
- All failed logons are **interactive (type 2)** or **unlock (type 7)**, i.e., console-based, not network/remote logon types (e.g., type 3, 10) typically seen in brute-force or credential-stuffing attacks.
- Only **two** failed attempts occurred before lockout — a small, human-consistent number, not the high-volume rapid attempts typical of automated attacks.
- The account was successfully used to log on **immediately after** the helpdesk unlock (4624 at 08:23:44) from the **same workstation**, with no further failures — consistent with the correct user regaining access, not an attacker being blocked.

## Recommendations / Corrective Actions

1. **Implement self-service password reset/unlock (SSPR)** to reduce dependency on helpdesk and reduce downtime for low-risk lockouts.
2. **Enable lockout warning notifications** (e.g., via GPO or logon banner) so users are alerted before the final failed attempt causes a lockout.
3. **Review lockout threshold policy** to confirm 2–3 attempts is appropriate, balancing security against user experience.
4. **Monitor for lockout patterns**: if this becomes frequent for `jsmith` or others, investigate potential password complexity/UX issues or password expiration timing.
5. **No security escalation required** for this specific incident based on current evidence; classify as user-error/operational and close after confirming no repeat lockouts.

## Conclusion

This incident is assessed as a routine, self-inflicted account lockout caused by repeated incorrect password entry at the user's own workstation, resolved through standard helpdesk unlock procedures. No indicators of compromise or malicious activity were identified. Recommended corrective actions focus on reducing user downtime via self-service tooling rather than security remediation.
