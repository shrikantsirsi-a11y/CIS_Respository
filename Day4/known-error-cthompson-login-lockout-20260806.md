Symptom: FINBRIDGE\cthompson was unable to log in from about 08:40 until service restoration at 09:09. The user experienced login failure and then account lockout behavior.

Cause: The verified root cause was account lockout triggered by repeated bad-password submissions. Evidence showed wrong-password attempts from DESKTOP-FB022 and additional wrong-password Kerberos pre-authentication attempts from source IP 10.10.8.112.

Scope: The incident affected a single user account, FINBRIDGE\cthompson. The involved systems/sign-in sources were DESKTOP-FB022 and source IP 10.10.8.112, with no known wider platform or policy change during the incident window.

Workaround: To restore service immediately, contain the repeated authentication attempts from DESKTOP-FB022 and 10.10.8.112 and restore account state. In this incident, the account was enabled at 09:08:14 and successful interactive logon was verified at 09:09:01.

Permanent fix: Remove or update stale stored credentials on the identified sources (DESKTOP-FB022 and 10.10.8.112) so wrong-password replay stops. Keep the lockout triage process that requires source host/IP identification before unlock, and migrate automation away from personal user credentials to managed service accounts where applicable.

How to spot it: Look for Event 4776 with error 0xC000006A (wrong password), repeated Event 4625 failures (including unknown user name or bad password and account locked out), Event 4740 account lockout, and repeated Event 4771 with failure code 0x18 (wrong password). Confirm recovery with Event 4722 (account enabled) and Event 4624 interactive logon success.