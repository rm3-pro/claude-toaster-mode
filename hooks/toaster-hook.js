#!/usr/bin/env node
const fs = require('fs');
const os = require('os');
const path = require('path');

const event = process.argv[2] || process.env.TOASTER_HOOK_EVENT || 'UserPromptSubmit';
const home = os.homedir();
const isCodex = Boolean(process.env.PLUGIN_DATA);
const isCopilot = Boolean(process.env.COPILOT_PLUGIN_DATA);

const HOOK_MSG = [
  'TOASTER MODE: answer/action first; fewest words; one recommendation; no preamble/postamble/hedging; safety caveats only.',
  'Broad multi-file searches -> Explore subagent; no tool-call narration; do not re-read or re-derive.',
  'Do not truncate requested detail: reviews, security notes, graphify/Obsidian/wiki output, walkthroughs, and explicit explanations may expand.',
  'After non-trivial code changes: delete sweep for dead code, duplicate logic, unused files/components, and unnecessary complexity.',
  'Before final: surface least-confident points and what the user may not realize; investigate material doubts.',
  'Secrets never in git: use env vars or ignored .env files. /toaster off to disable.',
].join(' ');

function uniq(values) {
  return [...new Set(values.filter(Boolean))];
}

function hostConfigDir() {
  if (process.env.TOASTER_HOST === 'claude') {
    return process.env.CLAUDE_CONFIG_DIR || path.join(home, '.claude');
  }
  if (process.env.TOASTER_HOST === 'codex') {
    return process.env.CODEX_HOME || path.join(home, '.codex');
  }
  if (isCodex) return process.env.CODEX_HOME || path.join(home, '.codex');
  return process.env.CLAUDE_CONFIG_DIR || path.join(home, '.claude');
}

function stateDirs() {
  return uniq([
    process.env.PLUGIN_DATA,
    process.env.COPILOT_PLUGIN_DATA,
    hostConfigDir(),
  ]);
}

function flagPaths() {
  return stateDirs().flatMap(dir => [
    path.join(dir, '.toaster-mode.off'),
    path.join(dir, 'toaster-mode.off'),
  ]);
}

function isEnabled() {
  return !flagPaths().some(file => fs.existsSync(file));
}

function setEnabled(enabled) {
  for (const file of flagPaths()) {
    try {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      if (enabled) fs.unlinkSync(file);
      else fs.writeFileSync(file, 'off\n', 'utf8');
    } catch (error) {
      if (enabled && error.code === 'ENOENT') continue;
    }
  }
}

function parseCommand(prompt) {
  const text = String(prompt || '').trim().toLowerCase();
  if (!text) return null;
  const parts = text.split(/\s+/);
  const cmd = parts[0].replace(/^[@$]/, '/');
  if (cmd !== '/toaster' && cmd !== '/ponytail:toaster') return null;
  const arg = parts[1] || 'status';
  if (['on', 'enable', 'enabled'].includes(arg)) return 'on';
  if (['off', 'disable', 'disabled'].includes(arg)) return 'off';
  return 'status';
}

function writeOutput(systemMessage, context) {
  if (isCopilot) {
    process.stdout.write(JSON.stringify(event === 'SessionStart' && context ? { additionalContext: context } : {}));
    return;
  }
  if (isCodex) {
    const output = { systemMessage };
    if (context) {
      output.hookSpecificOutput = {
        hookEventName: event,
        additionalContext: context,
      };
    }
    process.stdout.write(JSON.stringify(output));
    return;
  }
  process.stdout.write(context);
}

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  let prompt = '';
  try {
    const data = input ? JSON.parse(input.replace(/^\uFEFF/, '')) : {};
    prompt = data.prompt || '';
  } catch (error) {
    prompt = '';
  }

  const cmd = parseCommand(prompt);
  let status = '';
  let systemMessage = '';

  if (cmd === 'on') {
    setEnabled(true);
    status = 'TOASTER MODE ON';
    systemMessage = 'TOASTER:ON';
  } else if (cmd === 'off') {
    setEnabled(false);
    status = 'TOASTER MODE OFF';
    systemMessage = 'TOASTER:OFF';
  } else if (cmd === 'status') {
    status = 'TOASTER MODE: ' + (isEnabled() ? 'ON' : 'OFF');
    systemMessage = isEnabled() ? 'TOASTER:ON' : 'TOASTER:OFF';
  }

  if (!isEnabled() && !status) return;

  const context = [status, isEnabled() ? HOOK_MSG : ''].filter(Boolean).join('\n\n');
  writeOutput(systemMessage || 'TOASTER:ON', context);
});
