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

# --- Optional: survive /usr/local wipes across reboots ---
# This platform reboots often and /usr/local is wiped every time. If the user
# depends on a tool installed there (e.g. the Hermes agent), keep a full copy
# of the install under the home directory (which survives reboots) plus a
# manifest of its /usr/local/bin launchers, and restore both here when they
# go missing. The example below is for Hermes — uncomment and adapt it only
# if the user actually uses that tool. It only restores from copies the agent
# previously made with the user's approval; it never downloads or installs
# anything on its own. Because the manifest records whatever launchers exist
# (hermes, hermes-acp, hermes-web-ui, ...), newly installed launchers are
# picked up automatically. If the user upgrades the tool, refresh the home
# copy from the live install afterwards.
#
# HBIN="$HOME/hermes-agent-bin"
# mkdir -p "$HBIN"
# hermes_launcher() { # $1 = path in /usr/local/bin; true = Hermes launcher
#   [ -f "$1" ] || return 1
#   case "$(basename "$1")" in hermes*) return 0;; esac
#   [ "$(stat -c%s "$1" 2>/dev/null || echo 0)" -gt 102400 ] && return 1
#   grep -q "hermes-agent" "$1" 2>/dev/null
# }
# if [ -x /usr/local/bin/hermes ]; then
#   for f in /usr/local/bin/*; do
#     hermes_launcher "$f" || continue
#     n="$(basename "$f")"
#     cmp -s "$f" "$HBIN/$n" 2>/dev/null || cp -a "$f" "$HBIN/$n"
#   done
# else
#   if [ -x "$HOME/hermes-agent/venv/bin/python" ] && [ -f "$HOME/hermes-agent/hermes" ]; then
#     echo "$(date -u +%FT%TZ) [watchdog] hermes missing -> restoring from ~/hermes-agent" >> "$LOG"
#     mkdir -p /usr/local/lib /usr/local/bin
#     if [ -e /usr/local/lib/hermes-agent ] && [ ! -L /usr/local/lib/hermes-agent ]; then
#       rm -rf /usr/local/lib/hermes-agent
#     fi
#     ln -sfn "$HOME/hermes-agent" /usr/local/lib/hermes-agent
#     for w in "$HBIN"/*; do
#       [ -f "$w" ] || continue
#       cp -a "$w" "/usr/local/bin/$(basename "$w")"
#     done
#     echo "$(date -u +%FT%TZ) [watchdog] hermes restored" >> "$LOG"
#   else
#     echo "$(date -u +%FT%TZ) [watchdog] hermes missing and no ~/hermes-agent copy; ask the user before installing anything" >> "$LOG"
#   fi
# fi
