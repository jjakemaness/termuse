#!/bin/bash
# TerMuse one-shot setup.
#
# Checks dependencies, generates fresh secrets into config.json
# (gitignored — NEVER commit it), creates the tmux session, and starts
# the relay bridge. After this, the agent still needs to:
#   1. verify a terminal round-trip (see below), and
#   2. install the watchdog on its scheduler (every 5 minutes):
#        bash /path/to/termuse/scripts/watchdog.sh
#
# Re-running is safe; use --reset to generate brand-new secrets.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
CFG="$ROOT/config.json"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing dependency: $1 — please install it first" >&2; exit 1;
  }
}
need tmux; need node; need curl; need openssl

if [ -f "$CFG" ] && [ "${1:-}" != "--reset" ]; then
  echo "config.json already exists. Reusing it (pass --reset to regenerate)."
else
  SESSION="termuse-$(openssl rand -hex 3)"
  OUT="tm-out-$(openssl rand -hex 16)"
  INP="tm-in-$(openssl rand -hex 16)"
  cat > "$CFG" <<EOF
{
  "tmuxSession": "$SESSION",
  "topicOut": "$OUT",
  "topicIn": "$INP",
  "createdAt": "$(date -u +%FT%TZ)"
}
EOF
  chmod 600 "$CFG"
  echo "generated fresh config.json (session: $SESSION)"
fi

SESSION="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).tmuxSession")"
OUT="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).topicOut")"
INP="$(node -p "JSON.parse(require('fs').readFileSync('$CFG','utf8')).topicIn")"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -x 120 -y 30
  echo "tmux session '$SESSION' created"
else
  echo "tmux session '$SESSION' already running"
fi

if pgrep -f "$SCRIPT_DIR/bridge.js" >/dev/null; then
  echo "bridge already running"
else
  nohup node "$SCRIPT_DIR/bridge.js" "$OUT" "$INP" "$SESSION" >> "$LOG_DIR/bridge.log" 2>&1 &
  echo "bridge started (log: $LOG_DIR/bridge.log)"
fi

echo
echo "Verify the round-trip:"
echo "  curl -s -d 'KEY:echo relay-ok' \"https://ntfy.sh/$INP\" >/dev/null && sleep 4 && tmux capture-pane -p -t $SESSION | tail -5"
echo
echo "Next: schedule 'bash $SCRIPT_DIR/watchdog.sh' every 5 minutes,"
echo "then build the TerMuse artifact per PROMPT.md."
