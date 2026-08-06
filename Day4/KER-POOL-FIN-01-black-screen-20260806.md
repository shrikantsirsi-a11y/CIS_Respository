Symptom: Users in POOL-FIN-01 could enter credentials successfully but then saw a black screen, and many sessions disconnected immediately after sign-in. Service behavior was inconsistent, with repeated reconnect attempts reported.

Cause: A graphics-stack regression introduced by the 02:00 AM POOL-FIN-01 image update caused dwm.exe to crash in igdumd64.dll during sign-in. This desktop initialization failure produced the black-screen and disconnect behavior.

Scope: The issue affected Azure Virtual Desktop host pool POOL-FIN-01 and impacted approximately 40% of users in that pool (Finance users). POOL-FIN-02 was not affected.

Workaround: Drain affected POOL-FIN-01 hosts to stop new session placement and redirect impacted users to available healthy capacity. Use this containment path immediately while corrective remediation is applied.

Permanent fix: Apply the recommended image/host correction remediation on POOL-FIN-01 and validate with controlled logons before reopening pool capacity. This action restored service, with user verification completed at 10:00 AM and no further issues reported.

How to spot it: On affected hosts, look for the sequence Event 21 (logon succeeded) -> Event 1000 (Application Error: dwm.exe faulting module igdumd64.dll, exception 0xc0000005) -> Event 9009 (Desktop Window Manager exited with error) -> Event 40 (session disconnected). In a healthy control pattern, Event 21 is followed by Event 9011 (DWM started successfully) with no corresponding Event 1000 for dwm.exe.