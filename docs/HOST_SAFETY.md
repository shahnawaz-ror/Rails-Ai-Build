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

### Why today’s verify loop is not enough

We already have useful pieces:

- `Intelligence.prepare!` — missing dirs + **gem migration version** heal  
- Builder / multitask **verify** — `zeitwerk` + tests (retry up to N)  
- `run_until_green` orchestration  
- Diff preview / apply / reject (Pro+)  
- `FixSkill`  

**Gap:** Those assume the host can still **boot**.  
If the agent bricks `config/application.rb` or `Gemfile`, `zeitwerk:check` never runs — and there is **no rollback of applied writes**.

Default Free mode: `diff_preview = false` → writes **auto-apply to disk**. That maximizes speed and maximizes blast radius.

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

## 3. Host Safety Loop (product design)

### Phase A — Prevent (before write lands)

| Guard | Rule |
|-------|------|
| **Session checkpoint** | Before agent run: snapshot contents of files about to change (or `git stash create`) |
| **Syntax gate** | For `*.rb`: `ruby -c` before apply |
| **Migration gate** | Version must be `\d{14}_…`; reject padded/short versions; optional dry parse |
| **Gemfile gate** | Gemfile/Gemfile.lock changes require confirm + `bundle check` in subprocess; never silent auto-apply on Free for Gemfile |
| **Boot-critical paths** | Soft-preview for `config/**`, `Gemfile*`, `db/migrate/**` even on Free |

### Phase B — Detect (after turn / after write set)

**Boot ladder** (cheap → expensive), tool: `host_safety_check`:

1. `ruby -c` on changed Ruby files  
2. `bundle check` if Gemfile touched  
3. `bin/rails runner 'puts :ok'` (true boot)  
4. `zeitwerk:check`  
5. Optional: smoke `GET` critical routes  
6. Existing tests / rubocop only if boot is green  

Failure class enum: `syntax | bundle | boot | zeitwerk | runtime_500 | test`

### Phase C — Isolate

- Run ladder in a **subprocess** (never trust in-process load after bad writes)  
- Team+: optional **shadow worktree** — agent writes there; promote only when green  
- IDE shows **Host unhealthy** banner; pause auto-apply until recover  

### Phase D — Heal (bounded)

| Class | Auto action |
|-------|-------------|
| Our migration version collision | Existing `Migrations::Intelligence.auto_heal!` |
| Missing dirs | Existing `Intelligence.ensure_workspace_dirs!` |
| Syntax/boot from known write set | **Rollback first**, then optional 1–2 `FixSkill` attempts |
| Never | Infinite `run_until_green` on a dead host |

### Phase E — Rollback (must ship)

| Capability | Behavior |
|------------|----------|
| `Changes::Store.rollback(id)` | Restore `old_content` for an applied change |
| `rollback_session(session_id)` | Undo entire agent turn write set (reverse order) |
| Checkpoint restore | `git checkout -- paths` / stash apply if process restarted |
| Verify failure policy | After N failed boot ladders → **auto-rollback**, then report |
| IDE | **Undo last agent run** button |

### Phase F — Report

- SSE phases: `prevent → detect → isolate → heal → rollback → report`  
- Payload: `{ healthy, failure_class, files, actions[], boot_ok, rolled_back }`  
- Doctor + `rails rails_ai_build:host_safety`  
- Audit events: `host_safety.detect|heal|rollback`

---

## 4. Integration into the agent loop

```
Ai::Driver.run / Tasks::Runtime
  → Intelligence.prepare!                 # today
  → HostSafety.checkpoint!(session)       # NEW
  → tools / write_file
       → prevent guards (syntax/migration/gemfile)
       → Changes::Store.record
  → end of turn
       → HostSafety.ladder                # NEW (before zeitwerk/test)
       → if boot fail → rollback + optional FixSkill (max 2)
       → else existing verify_builds loop
  → HostSafety.report → SSE + Doctor
```

---

## 5. Delivery slices

### Slice 1 — MVP (must)

1. Session file checkpoint  
2. `ruby -c` before applying `.rb` writes  
3. Subprocess `rails runner` boot check after agent turn  
4. `rollback_session` + IDE “Undo last run”  
5. Auto-rollback when boot check fails  

### Slice 2 — Gems & migrations

1. Gemfile change soft-preview + `bundle check`  
2. Migration pre-write validator (all migrations, not only gem collisions)  
3. Doctor check: `host_safety`  

### Slice 3 — Enterprise isolation

1. Shadow worktree promote-on-green  
2. Routes smoke tests  
3. Policy: never auto-apply boot-critical paths without approval  

---

## 6. Acceptance scenarios

| ID | Scenario | Pass |
|----|----------|------|
| HS-01 | Agent writes invalid Ruby in `routes.rb` | Syntax gate OR boot fail → auto-rollback; app boots |
| HS-02 | Agent adds broken Gemfile line | Blocked or rolled back; `bundle check` green |
| HS-03 | Agent adds bad migration file | Validator or rollback; `db:migrate` not left half-broken |
| HS-04 | Verify fails twice | Rollback write set; IDE shows Undo + report |
| HS-05 | User clicks Undo last run | Files restored to checkpoint |
| HS-06 | Only gem migration version collision | Existing heal still works without full rollback |

---

## 7. What we tell the customer

**Before:** “AI might break your app; run tests.”  
**After:** “Every agent run is checkpointed. If boot breaks, we roll back automatically and show you exactly what was undone. You can also Undo last run in one click.”

That is the Cursor-class safety story for **in-app** agents — Cursor can trash a file too, but the desktop IDE stays open. Our gem shares the host process: **host safety is the product.**

---

## 8. Related

- [SRS.md](./SRS.md) — add Host Safety requirements under AI / Operate  
- [CLIENT_JOURNEY_MASTER_PLAN.md](./CLIENT_JOURNEY_MASTER_PLAN.md) — pillar “Operate”  
- Code today: `Intelligence`, `Migrations::Intelligence`, `Tasks::Runtime`, `Changes::Store`, `run_rails_check`  
- Not yet: rollback, boot ladder, Gemfile guard, shadow worktree
