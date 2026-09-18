# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use a private security advisory in GitHub, including affected version, reproduction steps, impact, and a suggested mitigation.

## Credential handling

Never commit provider keys or signing credentials. Rotate any credential that has appeared in a public branch or build log. Client-side obfuscation is not a security boundary; production provider calls should be proxied by a server that enforces authentication, quotas, and abuse controls.

## Privacy-sensitive permissions

Microphone access is requested only for voice typing. Clipboard and text contents are processed to provide keyboard features and must not be logged or transmitted unless the user explicitly invokes a provider feature.
