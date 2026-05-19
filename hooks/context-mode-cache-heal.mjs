#!/usr/bin/env node
// Plugin cache self-heal (auto-deployed).
// Fixes anthropics/claude-code#46915: auto-update bumps a plugin to a new
// version mid-session, the old version directory is removed, and any hook
// path resolved at session start (CLAUDE_PLUGIN_ROOT) becomes a dead link.
//
// Strategy: keep stale version paths alive as symlinks to the newest version
// found on disk. Two passes:
//   1. installed_plugins.json — original behavior, heals entries whose
//      installPath disappeared (registry/disk drift).
//   2. ~/.claude/<plugin>/sessions/stats-pid-*.json — heals versions that
//      were active in a running session but no longer exist on disk
//      (session/disk drift, the common case after auto-update).
// Pure Node.js, no shell.
import { existsSync, readdirSync, statSync, symlinkSync, lstatSync, unlinkSync, readFileSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { homedir } from "node:os";

const HOME = homedir();
const CACHE_ROOT = resolve(HOME, ".claude", "plugins", "cache");
const SYMLINK_TYPE = process.platform === "win32" ? "junction" : undefined;

function latestVersionDir(parent) {
  if (!existsSync(parent)) return null;
  const dirs = readdirSync(parent).filter(d => /^\d+\.\d+/.test(d) && statSync(join(parent, d)).isDirectory());
  if (!dirs.length) return null;
  dirs.sort((a, b) => {
    const pa = a.split(".").map(Number), pb = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) - (pb[i] || 0);
    return 0;
  });
  return dirs[dirs.length - 1];
}

function healMissing(targetPath) {
  if (!targetPath || existsSync(targetPath)) return;
  if (!resolve(targetPath).startsWith(CACHE_ROOT + sep)) return;
  const parent = dirname(targetPath);
  const latest = latestVersionDir(parent);
  if (!latest) return;
  try { if (lstatSync(targetPath).isSymbolicLink()) unlinkSync(targetPath); } catch {}
  try { symlinkSync(join(parent, latest), targetPath, SYMLINK_TYPE); } catch {}
}

try {
  // Pass 1: heal installPath entries from installed_plugins.json.
  const installedFile = resolve(HOME, ".claude", "plugins", "installed_plugins.json");
  if (existsSync(installedFile)) {
    const ip = JSON.parse(readFileSync(installedFile, "utf-8"));
    for (const entries of Object.values(ip.plugins || {})) {
      for (const e of entries) healMissing(e.installPath);
    }
  }

  // Pass 2: heal versions referenced by running sessions.
  // Plugins like context-mode write per-PID stats files containing the version
  // they resolved at startup. If that version dir was removed by auto-update,
  // recreate it as a symlink to the latest one in the same parent.
  const dotClaude = resolve(HOME, ".claude");
  for (const name of readdirSync(dotClaude, { withFileTypes: true })) {
    if (!name.isDirectory() || name.name === "plugins") continue;
    const sessionsDir = resolve(dotClaude, name.name, "sessions");
    if (!existsSync(sessionsDir)) continue;
    const cacheParent = resolve(CACHE_ROOT, name.name, name.name);
    if (!existsSync(cacheParent)) continue;
    const versions = new Set();
    for (const f of readdirSync(sessionsDir)) {
      if (!/^stats-pid-\d+\.json$/.test(f)) continue;
      try {
        const j = JSON.parse(readFileSync(join(sessionsDir, f), "utf-8"));
        if (typeof j.version === "string" && /^\d+\.\d+/.test(j.version)) versions.add(j.version);
      } catch {}
    }
    for (const v of versions) healMissing(join(cacheParent, v));
  }
} catch {}
