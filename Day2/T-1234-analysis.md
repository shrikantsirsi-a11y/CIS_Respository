# T-1234 Analysis: User Unable to Reset Domain Password, No Access to Phone

## Summary
User cannot reset their domain password and does not currently have access to their registered phone for MFA/verification.

## Impact
- **Who:** One reporting user.
- **How many:** 1 user confirmed.
- **Business urgency:** High—user is locked out of their account and unable to complete self-service password reset, blocking all work requiring domain credentials.

## Known Facts
- User needs to reset their domain password.
- Self-service password reset requires a step the user cannot complete because they lack access to their phone.
- No indication yet of account lockout, breach, or other security event.

## Missing Information to Gather
1. Is the phone completely unavailable (lost, broken, at home) or just temporarily inaccessible? (to-verify)
2. Is the phone the only registered MFA/verification method, or are there alternate methods (authenticator app on another device, email, security questions)? (to-verify)
3. Has the user attempted self-service password reset (SSPR) already, and what specific step failed?
4. Is the account currently locked out, or just needing a password reset/change?
5. Can the user's identity be verified throug h an alternate approved process (line manager confirmation, ID check, helpdesk identity verification procedure)? (to-verify)
6. Does the user have access to any other registered device or backup verification method?
7. Is this urgent due to an upcoming deadline, or a general access issue?
8. Has the user recently changed phone numbers or devices without updating MFA registration? (to-verify)

## Likely Category
**Identity & Access Management – Password Reset / MFA Recovery**

## First Diagnostic Step
1. Verify the user's identity through the approved DWP identity verification process (not via public AI) before taking any account action.
2. Check whether the user has any alternate registered MFA method available.
3. If no alternate method exists, follow the approved manual/assisted password reset and identity verification procedure per DWP identity management policy. (to-verify)

---

**Next Steps:** Confirm identity through an approved verification channel before any password reset action is performed.
