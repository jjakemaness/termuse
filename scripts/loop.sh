#!/bin/bash
# TerMuse keepalive loop — the fallback "scheduler" for platforms with no
# cron and no systemd (many agent runtimes are bare containers).
#
# Runs watchdog.sh every few minutes. Safe to start from a shell profile:
# every new terminal tries, and all but the first exit immediately.
#
# Started for you by scripts/install.sh. Stop it with:
#   kill "$(cat ~/.termuse/loop.pid)"
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${TERMUSE_STATE:-$HOME/.termuse}"
PIDF="$STATE/loop.pid"
HB="$STATE/loop.heartbeat"
INTERVAL="${TERMUSE_INTERVAL:-300}"

mkdir -p "$STATE" || exit 1

# Is another copy already running?
#
# We use a heartbeat timestamp rather than checking the pidfile's process.
# $STATE lives under $HOME and survives reboots, so a pidfile outlives the
# process it names — and pid numbers get recycled, so "is that pid alive?"
# can match something unrelated and leave us assuming a loop runs when none
# does. A timestamp cannot be wrong that way: either it is recent or it isn't.
STALE=$(( INTERVAL * 2 + 30 ))
if [ -f "$HB" ]; then
  then_ts="$(cat "$HB" 2>/dev/null || echo 0)"
  case "$then_ts" in ''|*[!0-9]*) then_ts=0 ;; esac
  if [ "$(( $(date +%s) - then_ts ))" -lt "$STALE" ]; then
    exit 0
  fi
fi

echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT INT TERM

while :; do
  date +%s > "$HB"
  bash "$SCRIPT_DIR/watchdog.sh" >/dev/null 2>&1
  sleep "$INTERVAL"
done
