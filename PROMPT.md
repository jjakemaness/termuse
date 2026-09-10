# The TerMuse prompt

**This file is the whole product.** Everything below the divider is a
build spec written for your agent, not for you.

### How to use it

1. Copy **everything below the `---` divider** (the whole thing — it's one
   message, don't trim it).
2. Open your Muse Spark and paste it, together with a link to this repo:

   > Build this for me. Repo: `https://github.com/jjakemaness/termuse`
   >
   > *(paste the prompt here)*

3. Send it and wait. Your agent will read the repo, install and verify the
   relay on its own machine, build your private TerMuse page, test every
   control, and reply with a link.

### What to expect

- **You install nothing.** No downloads, no tokens to paste, no config to
  edit. If your agent asks you to do any of that, it went off-script —
  point it back at section 3 ("dead ends").
- **It takes a few minutes**, mostly spent on the verification pass.
- **You get one private link** at the end, plus a short security briefing
  in your agent's own words.
- **The link stays live** across reboots — a watchdog keeps the relay up
  until you tell your agent to remove it.

### Rerunning it

Safe. `setup.sh` reuses your existing config unless you pass `--reset`.
Paste the prompt again any time the page needs rebuilding.

---

You are setting up **TerMuse** for your user: a private, hosted page
where they can watch everything you do on your computer — your live
terminal on the left, a fully interactive browser on the right — and take
over either side at any time. This is a proven design. Follow it exactly,
especially the "dead ends" section: several approaches were tried and
failed before this one worked. Do not repeat them.

## 0. Read the repo first

The repo you were given contains:

- `scripts/bridge.js` — zero-dependency Node relay between a tmux session
  and a browser viewer, over ntfy.sh (plain HTTPS).
- `scripts/watchdog.sh` — keeps the tmux session and bridge alive; run it
  on a schedule.
- `scripts/setup.sh` — one-shot setup: dependency checks, fresh secrets in
  `config.json`, tmux session creation, bridge start.
- `ARCHITECTURE.md` — how the pieces fit together.
- `SECURITY.md` — tradeoffs you must disclose to the user.

Read all of them before you start.

## 1. Terminal relay (your machine)

1. Run `bash scripts/setup.sh`. It generates `config.json` with a random
   tmux session name and two unguessable ntfy.sh topics. **Never commit
   `config.json`, never show the topic names to anyone but the user, and
   never reuse topics across users.**
2. Verify the round trip yourself: POST `KEY:echo relay-ok-<random>` to the
   in-topic, wait a few seconds, then `tmux capture-pane -p -t <session>`
   and confirm your marker appears. If it doesn't, debug until it does —
   do not proceed on a broken relay.
3. Install `bash <repo>/scripts/watchdog.sh` on your scheduler to run every
   5 minutes. This recreates the tmux session and restarts the bridge after
   reboots. Confirm it is scheduled and tell the user it is always-on.

## 2. Build the TerMuse artifact

Build a **private** hosted artifact (it must never be public or shareable —
it exposes the user's agent terminal). Name it "TerMuse".

**Layout:** terminal pane on the left, browser pane on the right, single page.

**Terminal pane (all of this is required):**
- A real interactive text terminal, not screenshots. It shows the live
  tmux session and the user can type commands into it.
- You (the agent) get two server actions: one that returns the current
  pane content, one that sends keystrokes/commands to the session.
- Wire the actions to the tmux session directly when your action runtime
  shares the machine (preferred, lowest latency); otherwise route through
  the relay topics from `config.json`.
- Round trip (user types → output appears) must be a few seconds at most.

**Browser pane (all of this is required):**
- An address bar. Two rendering modes chosen by URL:
  - Public `http(s)` URLs render in an iframe.
  - Agent-localhost URLs (`localhost` / `127.0.0.1`, i.e. servers on YOUR
    machine) render through a **screenshot relay**: your action runtime
    keeps one persistent Chromium session, and every interaction returns a
    fresh PNG screenshot. This is the key trick — the viewer browser never
    touches your localhost; your action runtime does, because it has
    loopback access.
- The relay must support these operations (exact schema):
  - `navigate` — go to a URL, return screenshot + title
  - `capture` — screenshot of the current page
  - `reload` — reload, return screenshot
  - `click` — `x`, `y` coordinates in the viewport
  - `type` — either `text` (normal typing) or `key` (one of: `Enter`,
    `Tab`, `Backspace`, `Escape`, `ArrowUp`, `ArrowDown`, `ArrowLeft`,
    `ArrowRight`)
  - `scroll` — `dx`, `dy` offsets
  - Viewport: width 320–1600, height 240–1200
- One persistent browser session across operations so state (logins,
  cookies, history) survives between interactions.
- **Follow mode:** the pane can follow YOUR browsing. Keep a shared
  follow-URL state with get/set actions; when you browse, the pane follows.
- **Symmetric control:** the user and you can both click, type, and scroll
  the relay browser, and both can type in the terminal. Neither side is
  view-only.

## 3. Dead ends — do NOT do any of these

These were all tried and failed. Do not revisit them:

- Downloaded HTML viewer files the user opens outside the app.
- Setup flows that depend on the user pasting query strings or tokens.
- Screenshot-stream "watch my screen" approaches for the terminal — the
  terminal must be real interactive text.
- Running a web server on your machine and expecting any browser you drive
  to reach it (it can't — use the relay).
- `data:` URLs for test pages (they crash browser automation runtimes).

## 4. Verify everything before handing it over

- Terminal: type a command in the pane yourself (via your send action) and
  confirm the output appears; confirm the user's typing also works.
- Relay: serve a temporary test page on your localhost with a button, a
  text input, and a tall scroll area. `navigate` to it through the relay,
  `click` the button and confirm its state change, focus the input and
  `type` text plus a special key, `scroll` and confirm movement. Then stop
  the test server.
- Public URL: load a public site in the iframe and confirm it renders.
- Follow mode: set a follow URL and confirm the pane follows.
- Only when all of the above pass, give the user the link.

## 5. Hand over + security briefing

Tell the user, in plain language:

- What you built and that the terminal relay is always-on (every 5-minute
  check), and how to turn it off (remove the scheduled watchdog).
- The honest tradeoff: the relay topics are unguessable but public — anyone
  holding the in-topic could inject shell commands. Their topics are fresh
  and known only to them; they should treat the in-topic like a password.
- That no personal info, keys, or their topics appear anywhere in the repo.

## Done criteria

The user can open one private page, see your live terminal, type in it,
see your browser, click/type/scroll in it, point it at public sites and at
your localhost servers, and have it follow your browsing. Nothing in the
repo identifies them.
