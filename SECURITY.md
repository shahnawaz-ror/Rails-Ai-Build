# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 2.9.x   | Yes |
| 2.8.x   | Yes |
| 2.7.x   | Yes |
| 2.6.x   | Yes |
| 2.5.x   | Yes |
| 2.4.x   | Yes |
| 2.3.x   | Yes |
| 2.2.x   | Yes (security fixes) |
| 1.5.x   | Best effort |
| < 1.5   | No |

## Reporting a vulnerability

**Please do not open public GitHub issues for security vulnerabilities.**

Email **security@rails-ai-build.dev** (or open a private security advisory on GitHub) with:

- Description of the issue
- Steps to reproduce
- Impact assessment (data exposure, RCE, etc.)
- Suggested fix if available

We aim to acknowledge reports within **48 hours** and provide a fix or mitigation timeline within **7 days** for critical issues.

## Scope

In scope:

- Agent tool execution (`shell`, `write_file`, path traversal)
- API authentication and RBAC bypass
- SSRF via model provider URLs
- MCP / streaming endpoint abuse
- Secrets handling (API keys in logs or responses)
- Stripe webhook signature forgery
- Settings plan spoofing / settings token bypass

Out of scope:

- Misconfiguration by host applications (e.g. exposing `/rails_ai_build` without auth in production)
- Third-party AI provider outages or prompt injection in general

## Safe defaults

- Diff preview queues writes before applying (Pro+)
- Team+ approval workflow can require reviewer role to apply changes
- Path traversal guards in file tools
- Plan-based feature gates for sensitive capabilities
- Doctor task surfaces misconfiguration
- Encrypted API key store + settings mutation token
- Stripe webhooks verified with HMAC signature

Host applications should mount the engine behind authentication in production and restrict `allowed_tools` as needed.
