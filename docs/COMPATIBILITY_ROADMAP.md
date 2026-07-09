# Compatibility Roadmap — 1000 GitHub Rails Repos

> Generated from live GitHub discovery on **2026-07-09** — 1,000 public Ruby/Rails repositories analyzed.

## Executive summary

We discovered **1,000** public Rails-related repositories on GitHub (stars median **479**, max **58,715**). The gem today validates **synthetic archetype fixtures** labeled with OSS names — not real clones. This roadmap turns that into a **tiered, data-driven compatibility program** that guides gem improvements.

### Catalog snapshot (n=1000)

| Archetype | Count | % | Gem priority |
|-----------|------:|--:|--------------|
| `full_stack` | 858 | 86% | CRUD skills, Hotwire, RSpec generators |
| `engine` | 72 | 7% | Mount paths, isolated namespaces, gem packaging |
| `monolith` | 33 | 3% | Background jobs, multi-service, performance |
| `legacy` | 21 | 2% | Rails 6.1 paths, classic asset pipeline |
| `api_only` | 16 | 2% | JSON-only controllers, no view tools |

| Rails version (inferred) | Count |
|--------------------------|------:|
| 7.0 | 978 |
| 6.1 | 19 |
| 8.0 | 3 |

**Insight:** 86% of popular Rails repos are full-stack apps — optimize the default chat/CRUD path first. Only 7% are engines — dedupe engine checks by archetype, not by repo name.

---

## Phase 1 — Measurement (done in v1.6)

| Deliverable | Status |
|-------------|--------|
| GitHub discovery (`GithubDiscovery`) | ✅ 1000 repos |
| Catalog in `lib/.../data/rails_repos.yml` | ✅ |
| Tiered checker (`:smoke` / `:full`) | ✅ |
| Parallel + slice for CI | ✅ |
| Improvement report (`ImprovementPlan`) | ✅ |

### How to run

```bash
# Discover / refresh catalog from GitHub
GITHUB_TOKEN=... bundle exec rake rails_ai_build:compatibility:discover

# PR-safe smoke (5 archetype representatives)
bundle exec rake rails_ai_build:compatibility:smoke

# Full 1000-repo check (parallel)
COMPAT_WORKERS=8 bundle exec rake rails_ai_build:compatibility

# CI shard (e.g. job 2 of 4)
COMPAT_SLICE=2/4 bundle exec rake rails_ai_build:compatibility

# Improvement plan from results
bundle exec rake rails_ai_build:compatibility:plan
```

---

## Phase 2 — Gem improvements (broad plan)

### A. Developer experience (highest ROI — 858 full-stack repos)

1. **CRUD skill pack** — default `rails_ai_build:skill[crud]` should scaffold model + controller + request spec + factory matching conventions found in top repos (RSpec > Minitest in stars-weighted sample).
2. **Convention detector** — read `Gemfile`, `.rubocop.yml`, `spec/` vs `test/` and adapt agent system prompt automatically.
3. **Hotwire/Turbo awareness** — 12% of top repos mention hotwire/stimulus in topics; add skill for Turbo Frames/Streams.
4. **Test framework skill** — detect RSpec vs Minitest and generate matching tests.

### B. Engine & gem authors (72 engine repos)

1. **Engine mount generator** — `rails generate rails_ai_build:mount` with isolated namespace detection.
2. **Dummy app test harness** — Appraisal-style internal app per engine archetype (already started in v1.5 Combustion harness).
3. **Gemspec + gemspec path tools** — `list_files` should understand `lib/` + `app/` engine layout.

### C. API-only apps (16 repos)

1. **Skip view/write tools** when `config.api_only` detected.
2. **OpenAPI/JSON schema skill** — generate request/response contracts.
3. **Controller-only diff preview** — don't suggest ERB changes.

### D. Legacy / Rails 6.1 (21 repos)

1. **Appraisal 6.1 gemfile** — add `rails-6-1` appraisal (if feasible with gem deps).
2. **Classic autoloader warnings** — doctor check for `zeitwerk` vs `classic`.
3. **Sprockets vs Propshaft** — detect asset pipeline in `Gemfile`.

### E. Monoliths / enterprise (33 repos)

1. **Background job integration** — Sidekiq/Solid Queue detection (stars-heavy in sample).
2. **Multi-agent orchestration** — map to service-object extraction patterns.
3. **Audit + RBAC** — already Team-tier; align with GitLab/Discourse-style compliance hooks.

### F. Tooling hardening (all archetypes)

| Gap found in 1000-repo analysis | Fix |
|----------------------------------|-----|
| `grep` skips binary silently | ✅ invoke grep in edge-case test |
| `shell` tool not in compat path | Add optional `check_shell` tier-2 |
| `write_file` not in main checker | Add to tier-2 smoke |
| Rails 8 `model_name` column clash | ✅ fixed in v1.5 ApplicationRecord |
| No real `bundle install` in host apps | Phase 3 |

---

## Phase 3 — Real-repo validation (next quarter)

Tier **2** goes beyond synthetic fixtures:

1. **Shallow clone** top 50 repos by stars (discourse, gitlab, mastodon, etc.).
2. **`bundle install`** in Docker sandbox (Ruby 3.2 + 3.3 matrix).
3. **Mount gem** + `POST /rails_ai_build/chat` smoke test.
4. **Record failures** in `compatibility/results/` JSON for regression tracking.

Cost control: run nightly, not on every PR.

---

## Phase 4 — Community & marketplace

1. **Community packs from catalog** — top engine repos → marketplace skill packs (devise, sidekiq, pundit patterns).
2. **Repo-specific upgrade notes** — `Upgrade.steps_for` keyed by archetype.
3. **Public compatibility badge** — README shield from `rails_ai_build:compatibility:smoke`.

---

## Priority matrix (what to build first)

```
Impact ▲
  │  [CRUD skill]  [Convention detector]
  │  [Hotwire skill]     [Engine mount gen]
  │       [API-only mode]    [Real clone tier-2]
  └──────────────────────────────────────► Effort
```

**Execute now (v1.6):** measurement infra + smoke tier + improvement report.  
**Execute next (v1.7):** convention detector + CRUD skill improvements from catalog patterns.  
**Execute later (v1.8+):** real-repo Docker tier + marketplace packs from top repos.

---

## References

- Catalog: `lib/rails_ai_build/compatibility/data/rails_repos.yml`
- Discovery: `lib/rails_ai_build/compatibility/github_discovery.rb`
- Checker: `lib/rails_ai_build/compatibility/checker.rb`
- Plan generator: `lib/rails_ai_build/compatibility/improvement_plan.rb`
