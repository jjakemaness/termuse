# Architecture

## The problem

A Muse agent runs on its own machine in the cloud. Its human wants to see
everything it does — its terminal and its browser — live, and take over at
any time. Two hard constraints shape the design:

1. The human's browser can never reach the agent's machine directly
   (no shared network, tunnels and raw TCP are blocked).
2. The agent's action runtime *can* reach its own machine's localhost.

So everything the human sees is carried over plain HTTPS, and the agent's
runtime acts as the bridge to its own localhost.

## Components

```
Agent's machine                          Human's browser
─────────────────                        ───────────────
tmux session ◄──► bridge.js ◄──► ntfy.sh ◄──► TerMuse page
 (the agent's      (polls in-topic,        (terminal pane:
  live shell)       publishes pane          live text,
                    snapshots)              typeable)

Chromium ◄──► artifact action runtime ◄──► TerMuse page
 (persistent       (navigate/click/          (browser pane:
  session)          type/scroll → PNG         screenshots,
                    screenshot)               clickable)
```

### Terminal path

- The agent works in a `tmux` session (the source of truth — a real shell).
- `scripts/bridge.js` (zero npm deps) long-polls an ntfy.sh **in-topic**;
  messages starting with `KEY:` are fed into tmux via `send-keys`.
- Every ~1.5s it captures the pane (`tmux capture-pane`) and, when the
  content changed, publishes a snapshot to the **out-topic**.
- The TerMuse terminal pane subscribes to the out-topic and POSTs
  keystrokes to the in-topic. Round trip is typically 2–4 seconds.
- `scripts/watchdog.sh`, run every 5 minutes by the agent's scheduler,
  recreates the tmux session and restarts the bridge after reboots.
- Where the platform allows it, the artifact's terminal actions may talk
  to tmux directly instead of via ntfy (same machine, lower latency). The
  user-visible behavior is identical either way.

### Browser path

- Public URLs: rendered in an `<iframe>` in the user's browser. Simple,
  zero latency beyond normal browsing. (Some sites block framing; that's
  a web standard, not something this project can fix.)
- Agent-localhost URLs (`localhost`/`127.0.0.1`): the viewer browser could
  never reach these, so the artifact's action runtime drives one persistent
  Chromium session on the agent's side and returns PNG screenshots after
  every operation: `navigate`, `capture`, `reload`, `click(x, y)`,
  `type(text | special key)`, `scroll(dx, dy)`. Viewport 320–1600 × 240–1200.
  Round trip is typically 1–2 seconds.
- **Follow mode:** a shared follow-URL state lets the pane track the
  agent's own browsing.

## Why not simpler?

Earlier iterations tried: downloaded HTML viewers (broke on relay
networking), query-string setup flows (fragile, user-hostile),
screenshot-stream terminals (not interactive), and expecting driven
browsers to reach the agent's localhost (impossible — separate
infrastructure). The relay-over-HTTPS design is what survived contact
with reality: boring, standard protocols, no accounts, no tunnels.

## Latency budget

- Terminal keystroke → visible output: ~2–4s (relay polling).
- Browser click → fresh screenshot: ~1–2s.
- Both are inherent to bridging two machines over HTTPS, and both were
  accepted by the humans who use it daily.
