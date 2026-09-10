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
3. **Do not install the watchdog or schedule anything.** That is the user's
   step, not yours — they run `scripts/install.sh` from inside the finished
   terminal, which fetches the scripts straight from the repo and schedules
   them. Your job ends at a working, interactive split view.

   Two reasons this split exists, and both matter: the user gets the repo's
   exact bytes rather than your paraphrase of them, and fixes reach them by
   re-running one command instead of re-prompting you. Adding your own
   scheduled copy on top will fight theirs. Leave it alone.

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
- **Symmetric control — this is the feature people actually want, and the
  one most likely to get quietly dropped. Do not ship without it.**
  - The user can **type into the terminal pane** and their keystrokes reach
    the real shell. A terminal the user can read but not type into is a
    failed build, not a partial one.
  - The user can **click, type into, and scroll the browser pane**, and
    those actions hit the real page — not a static capture of it.
  - Neither pane is view-only, and neither is agent-only. Every control you
    have, the user has.
  - If your runtime cannot wire user input to a pane, say so plainly in the
    handover instead of shipping a viewer and calling it done. A read-only
    build is the single most common way this goes wrong.

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

Run every check below and **report the result of each one to the user with
the evidence** — the command you sent and the output you got back, the
element you clicked and how its state changed. Do not summarize this as
"tested and working"; the user cannot audit a claim, only evidence.

- **Terminal, your input:** send `echo termuse-check-$(date +%s)` and paste
  the exact line that came back.
- **Terminal, the user's input:** confirm the pane accepts typed input from
  the user's side. State which mechanism carries it. If you cannot verify
  this without the user, say so and ask them to type one command.
- **Browser, interaction:** serve a temporary page on your localhost with a
  button, a text input, and a tall scroll area. Through the relay:
  `navigate` to it, `click` the button and report the state change, focus
  the input and `type` text plus one special key and report what the field
  contains, `scroll` and report the offset moving. Then stop the test server.
- **Public URL:** load a public site in the iframe and confirm it renders.
- **Agent localhost:** load a real server of yours and confirm it renders.
- **Follow mode:** set a follow URL and confirm the pane follows.

**If any check fails, fix it before handing over the link.** Do not report
partial success as success. Shipping a link to a broken pane wastes far more
of the user's time than telling them a check failed.

## 5. Hand over + security briefing

Tell the user, in plain language:

- What you built, and the per-check evidence from section 4.
- **Their next step, quoted exactly so they can copy it.** Tell them to run
  this in the terminal pane you just gave them, and that it schedules the
  watchdog and makes their installs survive reboots:

  ```
  curl -fsSL https://raw.githubusercontent.com/jjakemaness/termuse/main/scripts/install.sh -o install.sh && bash install.sh
  ```

  Point them at the README's "Is it actually working?" checks as well.
- The honest tradeoff, if you used the ntfy relay: the topics are
  unguessable but public — anyone holding the in-topic could inject shell
  commands. Their topics are fresh and known only to them; they should treat
  the in-topic like a password. Say plainly which wiring you used.
- That no personal info, keys, or their topics appear anywhere in the repo.

## Done criteria

The user can open one private page and **both watch and drive** it: read the
live terminal *and type into it*, see the browser *and click, type, and
scroll in it*, point it at public sites and at your localhost servers, and
have it follow your browsing. If they can see everything but change nothing,
you have not met these criteria. Nothing in the repo identifies them.
