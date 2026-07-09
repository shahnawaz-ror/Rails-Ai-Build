# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.4.x   | Yes       |
| 1.3.x   | Yes       |
| < 1.3   | No        |

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

Out of scope:

- Misconfiguration by host applications (e.g. exposing `/rails_ai_build` without auth in production)
- Third-party AI provider outages or prompt injection in general

## Safe defaults

- Diff preview queues writes before applying (Pro+)
- Path traversal guards in file tools
- Plan-based feature gates for sensitive capabilities
- Doctor task surfaces misconfiguration

Host applications should mount the engine behind authentication in production and restrict `allowed_tools` as needed.
