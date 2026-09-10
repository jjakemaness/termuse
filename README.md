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

## Setup: paste one file to your agent

You don't install anything. You don't run anything. You don't configure
anything. **Your agent does all of it.**

1. Open **[`PROMPT.md`](PROMPT.md)**.
2. Copy everything below the `---` divider.
3. Paste it to your Muse Spark as a single message, along with a link to
   this repo:

   > Here's the repo: `https://github.com/jjakemaness/termuse`
   >
   > *(then the pasted prompt)*

4. Wait a few minutes. Your agent reads the repo, runs the setup, verifies
   the connection end to end, and hands you a private link.

Open the link. You're in.

### What you're actually giving your agent

Just two things — the repo and the prompt. The prompt is a complete build
spec: it tells your agent to run `scripts/setup.sh`, verify a real
round-trip through the relay, schedule the watchdog, build your private
TerMuse page, test every control, and only then give you the link. It also
lists the approaches that were tried and **failed**, so your agent doesn't
burn an hour rediscovering them.

You are not asked to paste tokens, edit config files, or open anything
outside the app. If a setup step ever asks you to, something has gone wrong.

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
| `scripts/setup.sh` | One-shot setup your agent runs: deps, secrets, tmux, bridge. |
| `scripts/bridge.js` | The terminal relay. Zero npm dependencies. |
| `scripts/watchdog.sh` | Keeps the relay alive; scheduled every 5 minutes. |
| `config.example.json` | Shape of the generated `config.json` (the real one is gitignored). |
| `ARCHITECTURE.md` | How the pieces fit together, and why the simpler designs failed. |
| `SECURITY.md` | Threat model and tradeoffs. |

## Requirements

On the agent's machine: `tmux`, `node`, `curl`, `openssl`, and a scheduler
(cron or the platform's equivalent). On yours: a browser.

No accounts to create, no tunnels, no extensions, no npm install.

## Turning it off

Remove the scheduled `watchdog.sh` and kill the bridge process. The relay
stops; nothing is left listening. To rotate your topics after a suspected
leak, run `scripts/setup.sh --reset` and have your agent rewire the page.

## License

MIT — see [LICENSE](LICENSE). Use it, change it, ship it, sell it. Just
keep the notice, and don't expect a warranty.
