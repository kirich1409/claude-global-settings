#!/usr/bin/env bash
# MemPalace emergency save hook (PreCompact event).
# Forces Claude to save everything to the palace before the context window
# is compacted and detail is lost. Based on https://mempalaceofficial.com/guide/hooks.html
set -euo pipefail

command -v mempalace >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
trigger=$(printf '%s' "$payload" | jq -r '.trigger // "auto"')

jq -n --arg trigger "$trigger" '{
  decision: "block",
  reason: ("MemPalace emergency save — context is about to be compacted (trigger: \($trigger)). Before compaction, file ALL important context to the palace: active topics, decisions, open TODOs, entities, locations, dates, numbers, and verbatim quotes from the full session. Classify into the correct wings/rooms/closets/drawers via mempalace MCP tools or the `mempalace` CLI. Only then let the compaction proceed.")
}'
