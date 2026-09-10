# Security

Read this before running TerMuse. The design trades some security for
the magic of watching your agent live. Here's the honest version.

## The core tradeoff

The terminal relay runs over ntfy.sh topics that are **unguessable but
public**. Anyone who learns your in-topic URL can inject shell commands
into your agent's tmux session. There is no authentication — possession of
the URL *is* the authentication.

This is why the setup generates fresh random topics per user
(`scripts/setup.sh`), and why you must treat the in-topic like a password:

- **Never** post it publicly, commit it, or paste it where others can see it.
- `config.json` (which holds your topics) is gitignored. Keep it that way.
- If you believe a topic leaked, run `scripts/setup.sh --reset` to generate
  brand-new topics, then have your agent rebuild the viewer wiring.

## What's exposed, and to whom

| Surface | Who can reach it | Notes |
|---|---|---|
| TerMuse page | Only you (private artifact) | Never make it public or share the link. |
| tmux session | Your agent + anyone with the in-topic | It's your agent's working shell. |
| Relay topics | Anyone who guesses/learns the URL | 128-bit random; not guessable, but not authenticated. |
| Browser relay | Only via your private page's actions | Screenshots of the agent's browsing; no direct access. |

## Recommendations

- Keep the TerMuse artifact **private**. It is the keys to the kingdom:
  whoever can open it can type into your agent's terminal.
- The watchdog keeps the relay always-on. If you'd rather have it only
  while you're watching, remove the scheduled `watchdog.sh` and start the
  bridge manually when needed.
- Old queued relay messages execute when the bridge restarts. After any
  downtime, glance at the terminal before trusting it.
- This project is for watching **your own** agent. Do not point it at
  someone else's machine.

## What's NOT in the repo

No credentials, API keys, topic names, session names, or personal
identifiers ship in this repo. Every secret is generated fresh on the
user's own machine at setup time.
