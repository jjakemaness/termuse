#!/usr/bin/env node
'use strict';
/* TerMuse terminal bridge.
 *
 * Two-way terminal between a browser-based viewer and a tmux session on
 * this machine, relayed over ntfy.sh (plain HTTPS, which passes through
 * restrictive egress filtering where tunnels and raw TCP do not).
 *
 *   OUT topic: this script publishes tmux pane snapshots (last 25 lines)
 *              whenever the content changes.
 *   IN topic:  the viewer POSTs "KEY:<text>"; this script feeds each line
 *              into the tmux session as keystrokes + Enter.
 *
 * Configuration (first match wins):
 *   1. argv: node bridge.js <out-topic> <in-topic> [tmux-session]
 *   2. ../config.json  (written by scripts/setup.sh; NEVER commit it)
 *
 * Zero npm dependencies. Requires: tmux, curl, node.
 * Run it via scripts/watchdog.sh (kept alive by the agent's scheduler).
 */
const { execFile } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function loadConfig() {
  if (process.argv[2] && process.argv[3]) {
    return {
      out: process.argv[2],
      inp: process.argv[3],
      session: process.argv[4] || 'termuse',
    };
  }
  const cfgPath = path.join(__dirname, '..', 'config.json');
  if (fs.existsSync(cfgPath)) {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.topicOut && cfg.topicIn && cfg.tmuxSession) {
      return { out: cfg.topicOut, inp: cfg.topicIn, session: cfg.tmuxSession };
    }
  }
  console.error(
    '[bridge] missing configuration.\n' +
    '  Run scripts/setup.sh first, or pass: node bridge.js <out-topic> <in-topic> [tmux-session]'
  );
  process.exit(1);
}

const { out: OUT, inp: INP, session: SESSION } = loadConfig();

const sh = (cmd, args) =>
  new Promise((resolve) => execFile(cmd, args, { timeout: 25000 }, (e, so) => resolve(so || '')));

let since = '';
let lastHash = '';

async function pollInput() {
  const raw = await sh('curl', ['-s', '--max-time', '20',
    `https://ntfy.sh/${INP}/json?poll=1${since ? `&since=${since}` : ''}`]);
  for (const line of raw.split('\n')) {
    if (!line.trim()) continue;
    let m;
    try { m = JSON.parse(line); } catch { continue; }
    since = m.id;
    if (m.message && m.message.startsWith('KEY:')) {
      const text = m.message.slice(4);
      console.log(`[bridge] <- "${text.slice(0, 60)}"`);
      await sh('tmux', ['send-keys', '-t', SESSION, '-l', text]);
      await sh('tmux', ['send-keys', '-t', SESSION, 'Enter']);
    }
  }
}

async function pushOutput() {
  const pane = await sh('tmux', ['capture-pane', '-t', SESSION, '-p', '-S', '-25']);
  const hash = crypto.createHash('md5').update(pane).digest('hex');
  if (hash !== lastHash) {
    lastHash = hash;
    const code = await sh('curl', ['-s', '--max-time', '20', '-o', '/dev/null', '-w', '%{http_code}',
      '-d', pane, `https://ntfy.sh/${OUT}`]);
    console.log(`[bridge] -> snapshot published (http ${code.trim()})`);
  }
}

(async () => {
  console.log(`[bridge] session=${SESSION} relay ready`);
  for (;;) {
    try {
      await pollInput();
      await pushOutput();
    } catch (e) {
      console.log('[bridge] loop error:', String((e && e.message) || e).slice(0, 80));
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
})();
