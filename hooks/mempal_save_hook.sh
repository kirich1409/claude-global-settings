#!/usr/bin/env bash
# MemPalace auto-save hook (Stop event).
# Blocks Claude every SAVE_INTERVAL human messages so it files memories
# into the palace before stopping. Based on https://mempalaceofficial.com/guide/hooks.html
set -euo pipefail

# No-op on machines without the mempalace CLI (this file is git-synced).
command -v mempalace >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

SAVE_INTERVAL="${MEMPAL_SAVE_INTERVAL:-15}"
STATE_DIR="${MEMPAL_STATE_DIR:-$HOME/.mempalace/hook_state}"
mkdir -p "$STATE_DIR"

payload="$(cat)"
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty')
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty')
stop_active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')

# Claude re-invokes Stop after we block once; this flag breaks the loop.
[[ "$stop_active" == "true" ]] && exit 0
[[ -z "$session_id" || -z "$transcript" || ! -f "$transcript" ]] && exit 0

state_file="$STATE_DIR/${session_id}.last_save"
last_saved=0
[[ -f "$state_file" ]] && last_saved=$(tr -cd '0-9' <"$state_file" || echo 0)
[[ -z "$last_saved" ]] && last_saved=0

# JSONL transcript: one line per event. Count user-role entries.
human_count=$(jq -rs '[.[] | select(.type=="user" and (.message.role // "")=="user")] | length' "$transcript" 2>/dev/null || echo 0)
[[ -z "$human_count" ]] && human_count=0

since=$(( human_count - last_saved ))
(( since < SAVE_INTERVAL )) && exit 0

printf '%s' "$human_count" >"$state_file"

# Optional convo mining on each checkpoint.
if [[ -n "${MEMPAL_DIR:-}" && -d "$MEMPAL_DIR" ]]; then
  (mempalace mine "$MEMPAL_DIR" >/dev/null 2>&1 &) || true
fi

# Block stop → Claude reads `reason`, files the memories, then stops.
jq -n --argjson n "$SAVE_INTERVAL" '{
  decision: "block",
  reason: ("MemPalace checkpoint: \($n) human messages since last save. Before stopping, file the key topics, decisions, entities, and verbatim quotes from the recent exchange into the palace (wings/rooms/closets/drawers) via the mempalace MCP tools or `mempalace` CLI. After saving, stop normally — this hook will not re-fire in the same stop cycle.")
}'
