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

if [ ! -f "$CFG" ]; then
  echo "$(date -u +%FT%TZ) [watchdog] $CFG missing; run scripts/setup.sh first" >> "$LOG"
  exit 1
fi

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
