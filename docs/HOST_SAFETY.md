# Host Safety — The Real Problem After Integration

**Product truth:** Once a customer mounts `rails_ai_build` in *their* app, the AI is not coding in a sandbox by default — it writes into the live Rails tree. One bad edit can take down boot, migrations, or `bundle`.

This document is the **problem statement + solution contract** for that risk.

---

## 1. Problem statement (founder-level)

> **A customer integrated our gem into their production Rails app. The agent added a syntax error, a broken migration, or a bad gem. The app now fails to boot or returns 500s. How do we make sure the product heals itself — instead of leaving them with a dead app and a support ticket?**

That is not a “nice-to-have.” That is **trust**. If we don’t own this loop, agencies and enterprises will not keep the gem mounted.

### Failure classes we must handle

| Class | Example | Symptom |
|-------|---------|---------|
| **Syntax** | Broken `routes.rb` / controller | App won’t boot; IDE/engine dies with host |
| **Migration** | Invalid DSL, bad version, half-applied migrate | `db:migrate` / boot fails |
| **Gemfile** | Bad gem name / version / source | `bundle` broken; nothing runs |
| **Runtime 500** | Nil error in a controller the agent “fixed” | App boots but critical routes 500 |
| **Zeitwerk / load** | Wrong constant / file name | Boot or eager-load fails |
| **Test red** | Specs fail after change | Quality gate (less severe than boot) |

---

## 2. Solution principle

**Keep the host bootable.**  
Prefer: *prevent → detect in isolation → rollback → then AI fix*  
Never: *unbounded “fix” on a dead process*.

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ PREVENT  │ → │ DETECT   │ → │ ISOLATE  │ → │ HEAL     │ → │ ROLLBACK │ → │ REPORT   │
│ guards   │   │ ladder   │   │ subprocess│  │ bounded  │   │ restore  │   │ doctor   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

---

## 3. Host Safety Loop (implemented in v2.6.0)

### Phase A — Prevent (`HostSafety::Guards`)

| Guard | Behavior |
|-------|----------|
| Session checkpoint | `git stash create` when repo available |
| Syntax gate | `ruby -c` for `.rb` / Gemfile before apply |
| Migration gate | Filename `\d{14}_name.rb` + `ActiveRecord::Migration` class |
| Gemfile gate | Reject empty gems; soft-preview + `bundle check` on apply/ladder |
| Boot-critical soft-preview | `config/**`, `Gemfile*`, `db/migrate/**` queue even when `diff_preview=false` |

### Phase B — Detect (`HostSafety::Ladder`)

1. `ruby -c` on changed Ruby / Gemfile  
2. `bundle check` if Gemfile touched  
3. `bin/rails runner 'puts :rab_boot_ok'` when boot-critical (or `host_safety_always_boot`)  
4. `zeitwerk:check` when Ruby changed  
5. Optional smoke `recognize_path` for `host_safety_smoke_paths`  
6. Runtime verify (zeitwerk+tests) remains in `Tasks::Runtime`; on final fail → `rollback_session`

Failure classes: `syntax | bundle | boot | zeitwerk | runtime_500 | test`

### Phase C — Isolate (`HostSafety::Shadow`)

- Ladder runs via subprocess commands (never in-process load after bad writes)  
- Optional **shadow worktree** (`host_safety_shadow_worktree = true`) — write there; **promote** only when green; **discard** on fail  
- IDE **Host unhealthy** banner + pause messaging  

### Phase D — Heal

| Class | Auto action |
|-------|-------------|
| Gem migration version collision | `Migrations::Intelligence.auto_heal!` |
| Missing dirs | `Intelligence.ensure_workspace_dirs!` |
| Syntax/boot/bundle from write set | **Rollback / shadow discard first**, optional FixSkill (`host_safety_fix_after_rollback`) |
| Never | Infinite `run_until_green` on a dead host |

### Phase E — Rollback

| Capability | Behavior |
|------------|----------|
| `Changes::Store.rollback(id)` | Restore one change |
| `rollback_session(session_id)` | Undo entire turn write set |
| Shadow discard | Host tree untouched |
| Verify failure policy | After N failed verify attempts → auto-rollback |
| IDE | **Undo last run** + banner |

### Phase F — Report

- SSE phases: `prevent → detect → isolate → heal → rollback → report` (`host_safety` event)  
- Payload: `{ healthy, failure_class, checks, actions[], rolled_back, promoted }`  
- Doctor + `rails rails_ai_build:host_safety`  
- Audit: `host_safety.detect|isolate|promote|rollback|report`

---

## 4. Integration

```
Ai::Driver.run / Tasks::Runtime
  → Intelligence.prepare!
  → HostSafety.begin_session!   # checkpoint + optional shadow
  → tools / write_file / run_generator
       → Guards (syntax/migration/gemfile)
       → soft-preview for boot-critical
  → end of turn
       → HostSafety::Ladder
       → healthy ? Shadow.promote! : rollback/discard (+ optional FixSkill)
  → HostSafety.report → SSE + Doctor
```

---

## 5. Config flags

| Flag | Default | Meaning |
|------|---------|---------|
| `host_safety` | `true` | Master switch |
| `host_safety_boot_check` | `true` | `rails runner` step |
| `host_safety_bundle_check` | `true` | `bundle check` when Gemfile changes |
| `host_safety_zeitwerk_check` | `true` | `zeitwerk:check` after Ruby changes |
| `host_safety_soft_preview` | `true` | Queue boot-critical on Free |
| `host_safety_shadow_worktree` | `false` | Isolate writes; promote-on-green |
| `host_safety_smoke_routes` | `false` | Route smoke after boot |
| `host_safety_smoke_paths` | `["/"]` | Paths for smoke |
| `host_safety_git_checkpoint` | `true` | `git stash create` |
| `host_safety_fix_after_rollback` | `false` | Bounded FixSkill |
| `host_safety_rollback_on_verify_fail` | `true` | Runtime final-fail rollback |

---

## 6. Acceptance scenarios

| ID | Scenario | Pass |
|----|----------|------|
| HS-01 | Invalid Ruby in `routes.rb` | Soft-preview or syntax/boot → rollback; app boots |
| HS-02 | Broken Gemfile line | Guard / bundle check / rollback |
| HS-03 | Bad migration file | Validator rejects or rollback |
| HS-04 | Verify fails N times | Rollback write set; IDE shows Undo + banner |
| HS-05 | User clicks Undo last run | Files restored |
| HS-06 | Gem migration version collision | Existing heal without full rollback |
| HS-07 | Shadow enabled + bad write | Discard; host untouched |
| HS-08 | Shadow enabled + green | Promote to host |

---

## 7. Customer message

**Before:** “AI might break your app; run tests.”  
**After:** “Every agent run is checkpointed (and optionally isolated). If boot or bundle breaks, we roll back automatically and show exactly what was undone. You can also Undo last run in one click.”

---

## 8. Code map

| Piece | Path |
|-------|------|
| Facade | `lib/rails_ai_build/host_safety.rb` |
| Guards | `lib/rails_ai_build/host_safety/guards.rb` |
| Ladder | `lib/rails_ai_build/host_safety/ladder.rb` |
| Shadow | `lib/rails_ai_build/host_safety/shadow.rb` |
| Checkpoint | `lib/rails_ai_build/host_safety/checkpoint.rb` |
| Tool | `lib/rails_ai_build/tools/host_safety_check_tool.rb` |
| Generator-first | `lib/rails_ai_build/generators/*` |
