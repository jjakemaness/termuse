#!/bin/bash
# TerMuse installer — run this yourself, in the TerMuse terminal pane.
#
# Phase 1 (your agent) builds the split view. This is phase 2: it installs
# the watchdog that keeps the view alive and makes terminal installs survive
# reboots. Running it by hand means you get the exact bytes from the repo
# instead of an agent's paraphrase of them.
#
#   curl -fsSL https://raw.githubusercontent.com/jjakemaness/termuse/main/scripts/install.sh -o install.sh
#   less install.sh          # read it first; it schedules a job and writes to $HOME
#   bash install.sh
#
# Safe to re-run: it is idempotent and never duplicates the schedule.
# Uninstall with: bash install.sh --uninstall
set -u

REPO_RAW="${TERMUSE_REPO_RAW:-https://raw.githubusercontent.com/jjakemaness/termuse/main}"
DIR="${TERMUSE_DIR:-$HOME/.termuse/app}"
CRON_TAG="# termuse-watchdog"

say() { printf '  %s\n' "$*"; }

if [ "${1:-}" = "--uninstall" ]; then
  echo "TerMuse: uninstalling"
  if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - && say "removed the schedule"
  else
    say "no schedule found"
  fi
  say "left in place: $DIR and the mirror at \$HOME/.termuse/usr-local"
  say "delete those by hand if you want them gone"
  exit 0
fi

echo "TerMuse installer"

# --- 1. dependencies ---------------------------------------------------------
missing=""
for c in curl tmux; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
if [ -n "$missing" ]; then
  say "missing required tools:$missing"
  say "install them and re-run"
  exit 1
fi
command -v node >/dev/null 2>&1 || say "note: node not found — only needed for the ntfy relay path"
command -v crontab >/dev/null 2>&1 || { say "crontab not found; cannot schedule. See README for your platform's scheduler."; exit 1; }

# --- 2. fetch the scripts into a location that survives reboots --------------
# $HOME persists on platforms that wipe /usr/local, which is the whole point.
mkdir -p "$DIR/scripts" "$DIR/logs" || exit 1
for f in watchdog.sh bridge.js setup.sh; do
  if curl -fsSL "$REPO_RAW/scripts/$f" -o "$DIR/scripts/$f.new"; then
    mv "$DIR/scripts/$f.new" "$DIR/scripts/$f"
  else
    rm -f "$DIR/scripts/$f.new"
    say "could not download $f — check network and that the repo is public"
    exit 1
  fi
done
chmod +x "$DIR/scripts/"*.sh
say "scripts installed to $DIR/scripts"

# --- 3. schedule the watchdog ------------------------------------------------
LINE="*/5 * * * * bash $DIR/scripts/watchdog.sh >/dev/null 2>&1 $CRON_TAG"
if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
  # Replace it, so an old path from a previous install cannot linger.
  { crontab -l 2>/dev/null | grep -v "$CRON_TAG"; echo "$LINE"; } | crontab - \
    && say "schedule updated (every 5 minutes)"
else
  { crontab -l 2>/dev/null; echo "$LINE"; } | crontab - \
    && say "scheduled every 5 minutes"
fi

# --- 4. first run: seed the mirror -------------------------------------------
bash "$DIR/scripts/watchdog.sh"
MIRROR="${TERMUSE_MIRROR_DIR:-$HOME/.termuse/usr-local}"
if [ -d "$MIRROR" ]; then
  say "mirrored $(find "$MIRROR" -type f 2>/dev/null | wc -l | tr -d ' ') files from /usr/local"
else
  say "nothing in /usr/local to mirror yet — that is fine"
fi

cat <<EOF

Done. What happens now:
  - the watchdog runs every 5 minutes and keeps your split view alive
  - anything you install from this terminal is mirrored into \$HOME and
    restored automatically if a reboot wipes /usr/local

Check it worked:
  tail -3 $DIR/logs/watchdog.log
  ls $MIRROR/bin 2>/dev/null | head

Now run the 5 checks in the repo README under "Is it actually working?" —
they confirm you can type in the terminal and click in the browser, which
is the part an agent can get wrong.
EOF
