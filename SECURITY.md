# Security

SABarchy runs inside the unsandboxed Omarchy shell with the current user's
permissions. Report security issues privately through GitHub's security
advisory feature rather than a public issue.

The bundled helper reads SABnzbd configuration locally and accepts only
loopback API endpoints. Proxy use and HTTP redirects are disabled so requests
cannot leave the loopback boundary. It does not transmit credentials to remote
hosts.

API response bodies and configuration input are capped at 1 MiB before
parsing. Server-returned collections, strings, numeric values, and serialized
helper output are independently bounded before data enters the shell. Snapshot
and action helpers are also terminated if they exceed their time budgets.

All SABnzbd-provided text is rendered as plain text. Job metadata is never
interpreted as rich text or used to load inline resources.
