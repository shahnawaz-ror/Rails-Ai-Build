# Agent Queue + Send / Stop

## Goal
Match modern agent UIs: **Send** to start, **Stop** to halt, and a clear **queue** for background agents (list → follow → cancel).

## Phases

### Phase 1 (this release — v2.10.1)
| Capability | Behavior |
|------------|----------|
| **Send / Stop (Agent & Plan first & Build)** | `AbortController` aborts the browser SSE fetch; UI returns to Send |
| **Queue Cancel (queued)** | `DELETE /tasks/:id` cancels before a worker claims the task |
| **Queue Stop (running)** | Sets `cancel_requested`; Runtime/Runner stop **between** LLM/tool steps |
| **Queue UX** | Tasks panel: status, Follow, Cancel/Stop actions |
| **Follow** | Open live SSE into the Agent chat for that task |

### Phase 2 (later)
| Capability | Behavior |
|------------|----------|
| Mid-HTTP LLM abort | Close the in-flight `Net::HTTP` socket when Stop is pressed |
| Mid-shell / generator kill | Track child PIDs and `kill_process_group!` on cancel |
| Multi-worker cancel registry | Map `task_id → Thread` with cooperative flags (no `Thread.kill`) |

## HTTP
- `POST /tasks` — enqueue
- `GET /tasks` — list (`cancellable`, `cancel_requested`)
- `DELETE /tasks/:id` — cancel queued **or** request stop if running
- `POST /tasks/:id/stream` — long-lived SSE follow

## Safety
Prefer cooperative cancel over `Thread.kill`. Stop may finish the current model/tool call, then exit cleanly.
