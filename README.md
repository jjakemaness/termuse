# TerMuse

**See the computer your Muse agent is actually using.**

Your Spark agent on [muse.ai](https://muse.ai) works on a real machine — a
real shell, a real browser, real files. You normally only see what it
chooses to tell you about that machine in chat.

TerMuse gives you the machine itself, in one page: **your agent's live
terminal on the left, a fully interactive browser on the right.** Every
command it runs, every page it opens. And you're not just watching — you
can type into that terminal and click in that browser yourself, at any
moment, in the same session your agent is using.

![TerMuse: the agent's live terminal on the left, its localhost app rendered
and clickable on the right](docs/termuse.png)

*Above: the agent just ran `npm install -g hermes-web-ui` and started it on
`localhost:8648` — you can read that happening in the left pane. The right
pane is that same localhost app, rendered and fully clickable, on a machine
your browser has no route to. Follow mode is on, and the divider is
draggable (40/60, 50/50, 60/40).*

## Why this exists

Two things are normally impossible from your side of the screen:

- **You can't see the agent's shell.** You get a summary of what it did.
  TerMuse gives you the actual pane, live, and lets you type in it.
- **You can't open the agent's localhost.** When your agent builds a web
  app and runs it on `localhost:3000`, that server exists only on *its*
  machine. Your browser has no route to it. TerMuse renders it anyway —
  and lets you click around in it.

That second one is the whole trick, and it's why this repo exists instead
of a browser extension.

## Setup

Two steps. Your agent builds the view; you run one command inside it.

### Step 1 — paste the prompt to your agent

1. Open **[`PROMPT.md`](PROMPT.md)**.
2. Copy everything below the `---` divider.
3. Paste it to your Muse Spark as a single message, with a link to this repo:

   > Here's the repo: `https://github.com/jjakemaness/termuse`
   >
   > *(then the pasted prompt)*

4. Wait a few minutes. Your agent builds the split view, tests every
   control, and hands you a private link with its results.

Open the link. You should have a terminal on the left and a browser on the
right, and you should be able to **type in one and click in the other**.

### Step 2 — run the installer in your new terminal

Only your agent can build the view. Everything after that is scripts, so you
run those yourself and get the repo's exact bytes instead of your agent's
paraphrase of them. In the **terminal pane**:

```bash
curl -fsSL https://raw.githubusercontent.com/jjakemaness/termuse/main/scripts/install.sh -o install.sh
less install.sh    # optional: read it first. it schedules a job and writes to $HOME
bash install.sh
```

That schedules the watchdog (which keeps the view alive across reboots) and
turns on install persistence, so anything you `npm install -g` or `pip
install` from this terminal still works after the machine restarts.

Re-run it any time to update. `bash install.sh --uninstall` removes the
schedule.

### What you're actually giving your agent

Two things: the repo link and the prompt. The prompt is a build spec — it
tells your agent exactly what to build, requires that **both panes accept
your input** rather than being view-only, makes it report per-check evidence
instead of claiming success, and lists the approaches that were tried and
**failed** so it doesn't burn an hour rediscovering them.

You are never asked to paste tokens or edit config files. If your agent asks
you to, it went off-script.

## Is it actually working?

The most common bad outcome isn't a crash — it's an agent handing you a
**view-only** page and reporting success. Spend a minute on these. All five
should pass:

| # | Do this | Expected |
|---|---|---|
| 1 | Type `echo hello` in the terminal pane | `hello` comes back |
| 2 | Click a button in the browser pane | its state changes |
| 3 | Click a text field and type | your text appears |
| 4 | Scroll the browser pane | the page moves |
| 5 | Put a `localhost:<port>` of your agent's in the address bar | its app renders |

**1–4 are the whole point.** If you can see both panes but can't change
anything, you have a screenshot viewer, not TerMuse — go back to your agent,
tell it which check failed, and point it at "Symmetric control" in
`PROMPT.md`. That section exists because this is the step agents skip.

## What you get

| | |
|---|---|
| **Real terminal** | Live `tmux` text, not screenshots. Selectable, scrollable, typeable. |
| **Real browser** | Click, type, and scroll any page — including your agent's `localhost`. |
| **Public sites too** | Point the address bar anywhere; public URLs render directly. |
| **Follow mode** | The browser pane tracks your agent as it browses. |
| **Symmetric control** | You and your agent share both panes. Neither side is view-only. |
| **Adjustable split** | Drag the divider, or snap to 40/60, 50/50, 60/40. |
| **Always on** | A watchdog restarts the relay after reboots. The link just works. |

## How it works

Your agent's machine and your browser share no network — no tunnels, no
open ports, no VPN. So TerMuse routes everything over plain HTTPS:

- **Terminal:** a zero-dependency Node bridge on the agent's machine
  publishes `tmux` pane snapshots to a private relay topic and reads your
  keystrokes back off a second one. Round trip is a few seconds.
- **Browser:** the page's action runtime drives one persistent Chromium
  session *on the agent's side* and returns a fresh screenshot after every
  click, keystroke, and scroll. Your browser never touches the agent's
  localhost — the agent's own runtime does, because it's already there.

Full detail in [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Read this before you run it

The relay topics are unguessable but **unauthenticated** — whoever holds
your in-topic URL can type into your agent's shell. Your topics are
generated fresh on your machine and belong only to you. Treat the in-topic
like a password, and keep your TerMuse page private.

The full, honest threat model is in [`SECURITY.md`](SECURITY.md). It's
short. Read it.

## Repo layout

| Path | What it is |
|---|---|
| **`PROMPT.md`** | **Start here.** The message you paste to your Muse Spark. |
| **`scripts/install.sh`** | **Step 2.** You run this in the terminal; schedules the watchdog and install persistence. |
| `scripts/setup.sh` | One-shot relay setup your agent runs: deps, secrets, tmux, bridge. |
| `scripts/bridge.js` | The terminal relay. Zero npm dependencies. |
| `scripts/watchdog.sh` | Keeps the view alive and restores installs after reboots. Runs every 5 min. |
| `scripts/loop.sh` | Keepalive fallback for platforms with no cron or systemd. |
| `config.example.json` | Shape of the generated `config.json` (the real one is gitignored). |
| `ARCHITECTURE.md` | How the pieces fit together, and why the simpler designs failed. |
| `SECURITY.md` | Threat model and tradeoffs. |

## Requirements

On the agent's machine: `tmux`, `curl`, and `node`/`openssl` if you use the
ntfy relay path. On yours: a browser.

**No scheduler required.** The installer uses `cron` or a `systemd` user
timer when they exist, and otherwise runs its own keepalive loop, re-armed
from your shell profile. Bare agent containers usually have neither, which
is why the fallback exists.

No accounts to create, no tunnels, no extensions, no npm install.

## Turning it off

```bash
bash install.sh --uninstall
```

That removes the schedule. Nothing is left listening. Your mirrored installs
stay in `~/.termuse/` until you delete them by hand — the uninstall tells you
where. To rotate relay topics after a suspected leak, run
`scripts/setup.sh --reset` and have your agent rewire the page.

## License

MIT — see [LICENSE](LICENSE). Use it, change it, ship it, sell it. Just
keep the notice, and don't expect a warranty.
