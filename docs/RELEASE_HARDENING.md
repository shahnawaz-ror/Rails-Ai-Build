# Release Hardening — 5,000-company scale

**Goal:** Ship a gem that agencies/enterprises can mount in production without bricking hosts, leaking paths, or melting under concurrent agents.

Think Cursor-class: **prevent bad actions**, **isolate blast radius**, **recover automatically**, **observe everything**.

## Threat model (mounted in customer Rails apps)

| Actor | Risk |
|-------|------|
| Unauthenticated internet on `/rails_ai_build` | Read source, seize bootstrap token, run agents |
| Malicious/compromised prompt | Path escape, shell RCE, Gemfile/boot break |
| Concurrent agents | Race on same tree, last-write-wins corruption |
| Retried webhooks/bots | Duplicate plan upgrades / duplicate agent runs |
| Multi-worker Puma | In-process RateLimit/Seats/Sessions diverge |

## Hardening pillars

1. **Auth boundary** — production requires engine token (or host auth); bootstrap locked down  
2. **Workspace boundary** — realpath containment, no request workspace override, symlink rejection  
3. **Tool boundary** — shell allowlist/argv, production shell off by default  
4. **Host Safety** — generators-first + prevent/detect/rollback (already v2.6+)  
5. **Concurrency** — mutexes, caps, TTLs on in-memory stores; prefer worktree isolation  
6. **Outbound** — SSRF + timeouts + TLS verify + webhook idempotency  
7. **Observability** — Doctor, health, audit, rate-limit headers  

## Delivery batches

| Batch | Scope | Status |
|-------|-------|--------|
| A | Plan + auth/workspace/path P0 | done |
| B | Shell + bot signatures P0 | done |
| C | Thread-safe stores + caps P1 | done |
| D | HTTP client + Stripe idempotency P1 | done |
| E | Gemspec/packaging + health + release notes | done |
| F | Circuit breaker + EventBus caps + activation singleton | done |
| G | SSRF mapped-IP/CGNAT, Discord replay, write/memory/queue edges | done |
| H | Merge to main + release notes | done |
| I | Session/read_file caps + rate-limit headers | done |
| J | Grep/logs caps + audit redaction | done |

## Acceptance (release gate)

- [x] No public workspace path override from HTTP  
- [x] Symlink escape rejected for read/write/list  
- [x] Production bootstrap cannot be seized anonymously  
- [x] `require_engine_token` protects GET workspace/settings reads  
- [x] Shell disabled or argv-allowlisted in production  
- [x] Slack/Discord reject unsigned traffic when secrets configured  
- [x] RateLimit/Changes/Seats/Sessions mutex + max size  
- [x] Provider HTTP has open/read timeouts  
- [x] Stripe event IDs idempotent  
- [x] Per-host circuit breaker on outbound HTTP  
- [x] EventBus capped + unsubscribe + clear on finished tasks  
- [x] Activation singleton unique guard  
- [x] SSRF blocks IPv4-mapped loopback + CGNAT  
- [x] Discord 5m replay window  
- [x] Write/diff/memory/queue caps; Changes#show content opt-in  
- [x] `gem build` + require smoke passes  
- [x] Full RSpec green (348 examples, 0 failures)  

## Multi-worker note

In-process RateLimit / Seats / Sessions / CircuitBreaker are **per Puma worker**.
For sticky multi-worker production at 5k tenants, front with a shared store (Redis)
or run one worker / sticky sessions — documented here so ops does not assume
cross-process consistency.

## Out of gem (ops)

- RubyGems publish keys, Stripe live products, Cloud SaaS, marketing
- Optional: `ed25519` gem for full Discord signature verify
- Optional: Redis adapters for seats/rate-limit/circuit across workers
