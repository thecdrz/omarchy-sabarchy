# Security

SABarchy runs inside the unsandboxed Omarchy shell with the current user's
permissions. Report security issues privately through GitHub's security
advisory feature rather than a public issue.

The bundled helper reads SABnzbd configuration locally and accepts only
loopback API endpoints. It does not transmit credentials to remote hosts.
