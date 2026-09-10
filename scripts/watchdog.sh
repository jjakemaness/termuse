#!/bin/bash
# TerMuse watchdog: keep the live terminal (tmux session + relay bridge)
# always up. Run every few minutes via the agent's scheduler (cron).
# Recreates anything missing after a machine reboot.
#
# Reads ../config.json (written by scripts/setup.sh; never commit it).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$SCRIPT_DIR/../config.json"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG="$LOG_DIR/watchdog.log"
mkdir -p "$LOG_DIR"

# The ntfy relay is only one of the two ways the terminal pane can be wired.
# Where the artifact's actions reach tmux directly (same machine), there is no
# config.json and nothing to keep alive here — so skip this section rather
# than exiting, because the reboot-persistence section below must still run.
if [ -f "$CFG" ]; then
  SESSION="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).tmuxSession")"
  OUT="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).topicOut")"
  INP="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).topicIn")"

  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "$(date -u +%FT%TZ) [watchdog] tmux session '$SESSION' missing -> recreating" >> "$LOG"
    tmux new-session -d -s "$SESSION" -x 120 -y 30
  fi

  if ! pgrep -f "$SCRIPT_DIR/bridge.js" >/dev/null; then
    echo "$(date -u +%FT%TZ) [watchdog] bridge down -> restarting" >> "$LOG"
    nohup node "$SCRIPT_DIR/bridge.js" "$OUT" "$INP" "$SESSION" >> "$LOG_DIR/bridge.log" 2>&1 &
    echo "$(date -u +%FT%TZ) [watchdog] bridge restarted" >> "$LOG"
  fi
fi

# --- Keep terminal installs alive across reboots -------------------------
# Some agent platforms wipe /usr/local on every reboot while $HOME persists.
# That silently destroys anything installed from the TerMuse terminal:
# `npm -g` (launchers in /usr/local/bin AND payloads in
# /usr/local/lib/node_modules), system pip, `curl | sh` installers, and
# hand-placed binaries. /usr/bin (apt, tmux, node) is unaffected.
#
# This mirrors /usr/local into $HOME each tick and restores it after a wipe.
# /usr/local/bin is already on the session PATH, so restored commands work
# immediately with no shell-config changes.
#
# The mirror is ADDITIVE BY DESIGN — it never deletes. A tick that runs while
# /usr/local is empty therefore cannot destroy the backup, which is the only
# failure here that would actually lose you something. The tradeoff: anything
# you deliberately uninstall returns after the next reboot unless you also
# delete it from the mirror.
#
# TERMUSE_MIRROR=0 disables. Harmless on platforms that never wipe.

USRLOCAL="${TERMUSE_USRLOCAL:-/usr/local}"
MIRROR="${TERMUSE_MIRROR_DIR:-$HOME/.termuse/usr-local}"
ALIVE="$USRLOCAL/.termuse-alive"

if [ "${TERMUSE_MIRROR:-1}" = "1" ] && mkdir -p "$USRLOCAL" 2>/dev/null && [ -w "$USRLOCAL" ]; then

  # Restore first. A missing sentinel plus a non-empty mirror means the tree
  # was wiped — the sentinel lives inside it, so a wipe takes it too.
  if [ ! -f "$ALIVE" ] && [ -n "$(ls -A "$MIRROR" 2>/dev/null)" ]; then
    echo "$(date -u +%FT%TZ) [watchdog] $USRLOCAL was wiped -> restoring from $MIRROR" >> "$LOG"
    if cp -a "$MIRROR"/. "$USRLOCAL"/ 2>>"$LOG"; then
      echo "$(date -u +%FT%TZ) [watchdog] $USRLOCAL restored ($(find "$USRLOCAL" -type f 2>/dev/null | wc -l | tr -d ' ') files)" >> "$LOG"
    else
      echo "$(date -u +%FT%TZ) [watchdog] $USRLOCAL restore reported errors; see above" >> "$LOG"
    fi
  fi

  # Then mirror forward, but only when there is something real to copy.
  if [ -n "$(ls -A "$USRLOCAL" 2>/dev/null)" ]; then
    mkdir -p "$MIRROR"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude .termuse-alive "$USRLOCAL"/ "$MIRROR"/ 2>>"$LOG"
    else
      cp -a "$USRLOCAL"/. "$MIRROR"/ 2>>"$LOG"   # full copy; correct, less efficient
      rm -f "$MIRROR/.termuse-alive"
    fi
    touch "$ALIVE"
  fi
fi
