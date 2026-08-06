# Personal AI Usage Charter: DWP Desktop and Endpoint Engineering

## Purpose

I use public AI assistants to improve clarity, accelerate routine work, and explore technical options. I remain accountable for every decision, instruction, script, and system change I make. Public AI is an aid, not an authority or a DWP data store.

## Appropriate Uses

I may use public AI assistants for desktop and endpoint work when prompts contain no DWP-sensitive information and no real user, device, or service data. Suitable uses include:

- Explaining public Microsoft documentation, Windows behaviour, PowerShell syntax, or standard networking concepts.
- Drafting generic PowerShell, batch, or configuration examples using invented names, paths, identifiers, and sample values.
- Improving the structure, clarity, or tone of non-sensitive knowledge articles, runbooks, user communications, and ticket templates.
- Creating generic troubleshooting checklists for issues such as slow devices, application launch failures, printer faults, VPN connectivity, or Windows update problems.
- Reviewing logic in a sanitised script or suggesting test cases, rollback steps, and questions to ask before an endpoint change.

## Uses I Will Not Make

I will not use a public AI assistant for:

- Live incident, service desk, asset, security, vulnerability, or change-management records containing non-public DWP information.
- DWP architecture, network designs, internal configuration, Intune/SCCM policies, endpoint baselines, internal URLs, hostnames, tenant details, logs, or screenshots.
- Security investigation material, access-control decisions, phishing content, malware indicators, forensic data, or information that could weaken DWP defences.
- Producing or approving actions that bypass security controls, monitoring, patching, access management, or the formal change process.
- Making operational decisions where an approved DWP tool, documentation source, specialist team, or escalation route is required.

## Data Handling: PII and Credentials

I will never enter end-user PII, credentials, authentication material, or sensitive operational data into a public AI assistant. This includes names, email addresses, phone numbers, National Insurance numbers, case or claim data, employee identifiers, device serial numbers, IP addresses, support tickets, tokens, passwords, recovery keys, certificates, and screenshots or logs containing such information. I will redact or replace real values with clearly fictional placeholders before asking for help. If I cannot safely sanitise the material, I will use approved DWP tools and processes instead.

## Generate Then Verify

Before I run an AI-generated script or make a system change, I will:

1. Read and understand every command, parameter, dependency, permission, and affected device scope.
2. Check the approach against approved DWP documentation, endpoint standards, and the relevant change and security controls.
3. Test in an approved non-production or limited-scope environment where available; confirm expected outcome, logging, and rollback.
4. Obtain the required approval before any production deployment or user-impacting change.
5. Record what was changed, the verification performed, and any follow-up or rollback action in the appropriate DWP system.

I will stop and seek advice when generated output is unclear, requests elevated access, changes security settings, deletes data, modifies registry or policy at scale, or differs from approved guidance.