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
# Safe to re-run: idempotent, and it never duplicates a schedule.
# Uninstall with: bash install.sh --uninstall
set -u

REPO_RAW="${TERMUSE_REPO_RAW:-https://raw.githubusercontent.com/jjakemaness/termuse/main}"
DIR="${TERMUSE_DIR:-$HOME/.termuse/app}"
STATE="${TERMUSE_STATE:-$HOME/.termuse}"
MIRROR="${TERMUSE_MIRROR_DIR:-$HOME/.termuse/usr-local}"
TAG="termuse-watchdog"

say() { printf '  %s\n' "$*"; }

# --- uninstall ---------------------------------------------------------------
if [ "${1:-}" = "--uninstall" ]; then
  echo "TerMuse: uninstalling"
  if command -v crontab >/dev/null 2>&1 && crontab -l 2>/dev/null | grep -q "$TAG"; then
    crontab -l 2>/dev/null | grep -v "$TAG" | crontab - && say "removed cron entry"
  fi
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc" ] && grep -q "$TAG" "$rc"; then
      grep -v "$TAG" "$rc" > "$rc.termuse-tmp" && mv "$rc.termuse-tmp" "$rc"
      say "removed the hook from $rc"
    fi
  done
  if [ -f "$STATE/loop.pid" ]; then
    kill "$(cat "$STATE/loop.pid")" 2>/dev/null && say "stopped the keepalive loop"
    rm -f "$STATE/loop.pid"
  fi
  say "left in place: $DIR and the mirror at $MIRROR"
  say "delete those by hand if you want them gone"
  exit 0
fi

echo "TerMuse installer"

# --- 1. dependencies ---------------------------------------------------------
missing=""
for c in curl tmux; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
if [ -n "$missing" ]; then
  say "missing required tools:$missing — install them and re-run"
  exit 1
fi

# --- 2. fetch the scripts somewhere that survives reboots --------------------
# $HOME persists on the platforms that wipe /usr/local, which is the point.
mkdir -p "$DIR/scripts" "$DIR/logs" "$STATE" || exit 1
for f in watchdog.sh loop.sh bridge.js setup.sh; do
  if curl -fsSL "$REPO_RAW/scripts/$f" -o "$DIR/scripts/$f.new"; then
    mv "$DIR/scripts/$f.new" "$DIR/scripts/$f"
  else
    rm -f "$DIR/scripts/$f.new"
    say "could not download $f — check the network and that the repo is public"
    exit 1
  fi
done
chmod +x "$DIR/scripts/"*.sh
say "scripts installed to $DIR/scripts"

# --- 3. seed the mirror NOW --------------------------------------------------
# Deliberately before scheduling: if no scheduler exists, you still walk away
# with your current /usr/local backed up rather than with nothing.
bash "$DIR/scripts/watchdog.sh"
if [ -d "$MIRROR" ]; then
  say "mirrored $(find "$MIRROR" -type f 2>/dev/null | wc -l | tr -d ' ') files from /usr/local"
else
  say "nothing in /usr/local to mirror yet — that is fine"
fi

# --- 4. schedule it, using whatever this platform actually has ---------------
SCHEDULED=""

if command -v crontab >/dev/null 2>&1; then
  LINE="*/5 * * * * bash $DIR/scripts/watchdog.sh >/dev/null 2>&1 # $TAG"
  if { crontab -l 2>/dev/null | grep -v "$TAG"; echo "$LINE"; } | crontab - 2>/dev/null; then
    SCHEDULED="cron (every 5 minutes)"
  fi
fi

if [ -z "$SCHEDULED" ] && command -v systemctl >/dev/null 2>&1 \
   && systemctl --user show-environment >/dev/null 2>&1; then
  UD="$HOME/.config/systemd/user"
  mkdir -p "$UD"
  cat > "$UD/termuse.service" <<EOF
[Unit]
Description=TerMuse watchdog
[Service]
ExecStart=/bin/bash $DIR/scripts/watchdog.sh
EOF
  cat > "$UD/termuse.timer" <<EOF
[Unit]
Description=TerMuse watchdog every 5 minutes
[Timer]
OnBootSec=30
OnUnitActiveSec=300
[Install]
WantedBy=timers.target
EOF
  if systemctl --user daemon-reload 2>/dev/null && \
     systemctl --user enable --now termuse.timer 2>/dev/null; then
    SCHEDULED="systemd user timer (every 5 minutes)"
  fi
fi

if [ -z "$SCHEDULED" ]; then
  # No cron, no systemd — common in agent containers. Run our own loop, and
  # re-arm it from the shell profile so it comes back after a reboot the
  # first time any terminal opens. $HOME persists, so the hook persists.
  HOOK="[ -n \"\${BASH_VERSION:-}\" ] && [ -f $DIR/scripts/loop.sh ] && nohup bash $DIR/scripts/loop.sh >/dev/null 2>&1 & # $TAG"
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$rc" ] || touch "$rc"
    if grep -q "$TAG" "$rc" 2>/dev/null; then
      grep -v "$TAG" "$rc" > "$rc.termuse-tmp" && mv "$rc.termuse-tmp" "$rc"
    fi
    echo "$HOOK" >> "$rc"
  done
  nohup bash "$DIR/scripts/loop.sh" >/dev/null 2>&1 &
  sleep 1
  if [ -f "$STATE/loop.pid" ] && kill -0 "$(cat "$STATE/loop.pid")" 2>/dev/null; then
    SCHEDULED="keepalive loop, pid $(cat "$STATE/loop.pid") (no cron/systemd here)"
  else
    SCHEDULED="keepalive loop (hook added to your shell profile)"
  fi
fi
say "scheduling: $SCHEDULED"

cat <<EOF

Done. What happens now:
  - the watchdog runs every 5 minutes and keeps your split view alive
  - anything you install from this terminal is mirrored into \$HOME and
    restored automatically if a reboot wipes /usr/local

Check it:
  tail -3 $DIR/logs/watchdog.log
  ls $MIRROR/bin 2>/dev/null | head

IMPORTANT — the mirror only protects what exists now. Anything already lost
to an earlier reboot has to be reinstalled once; it is protected after that.

Then run the 5 checks in the repo README under "Is it actually working?" —
they confirm you can type in the terminal and click in the browser, which is
the part an agent can get wrong.
EOF
