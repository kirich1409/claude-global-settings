#!/bin/bash
# fetch_issue.sh — fetch a single GitHub issue by ref and output JSON.
#
# USAGE:
#   fetch_issue.sh <issue-ref> [-R <owner/repo>] [--with-comments]
#
# <issue-ref> accepts:
#   - plain number:              206
#   - owner/repo#number:         kirich1409/krozov-ai-tools#206
#   - full URL:                  https://github.com/kirich1409/krozov-ai-tools/issues/206
#
# -R <owner/repo>  Override repository (takes precedence over ref-embedded repo).
#                  If omitted, resolved from ref or from `gh repo view`.
#
# --with-comments  Also fetch the comment thread. Off by default: comment bodies are
#                  unbounded and would bloat every caller that only needs the issue.
#
# All `gh` calls are wrapped in gh_with_timeout (see _common.sh) so a hung API aborts
# instead of freezing the caller.
#
# OUTPUT (stdout, JSON):
#   Success:
#     {
#       "number":   <int>,
#       "title":    <string>,
#       "state":    "OPEN"|"CLOSED",
#       "body":     <string>,
#       "labels":   [{"id":<string>,"name":<string>,"color":<string>},...],
#       "url":        <string>,
#       "node_id":    <string>,  -- GraphQL global node id (e.g. "I_kwDO...")
#       "created_at": <string>,  -- ISO-8601 UTC
#       "updated_at": <string>,  -- ISO-8601 UTC; staleness signal
#       "comments":   [ ... ]    -- only with --with-comments; oldest first:
#                                --   {"author":<string|null>,"created_at":<string>,
#                                --    "body":<string>,"edited":<bool>,"url":<string>}
#                                --   `edited` = body was changed after posting, so
#                                --   created_at understates its real age.
#     }
#   Error:
#     {"error":<string>,"code":<string>}
#   Exit code is non-zero on error.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

im_error() {
  local msg="$1" code="${2:-unknown}"
  printf '{"error":%s,"code":%s}\n' "$(printf '%s' "$msg" | jq -Rs .)" "$(printf '%s' "$code" | jq -Rs .)"
}

im_parse_ref() {
  # Sets globals: IM_NUMBER, IM_REPO (may be empty)
  local ref="$1"
  IM_NUMBER=""
  IM_REPO=""

  if [[ "$ref" =~ ^https?://github\.com/([^/]+/[^/]+)/issues/([0-9]+) ]]; then
    IM_REPO="${BASH_REMATCH[1]}"
    IM_NUMBER="${BASH_REMATCH[2]}"
  elif [[ "$ref" =~ ^([^#]+)#([0-9]+)$ ]]; then
    IM_REPO="${BASH_REMATCH[1]}"
    IM_NUMBER="${BASH_REMATCH[2]}"
  elif [[ "$ref" =~ ^([0-9]+)$ ]]; then
    IM_NUMBER="${BASH_REMATCH[1]}"
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  im_error "Usage: fetch_issue.sh <issue-ref> [-R <owner/repo>] [--with-comments]" "usage"
  exit 1
fi

RAW_REF="$1"
shift
REPO_OVERRIDE=""
WITH_COMMENTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -R) REPO_OVERRIDE="$2"; shift 2 ;;
    --with-comments) WITH_COMMENTS=1; shift ;;
    *)  im_error "Unknown flag: $1" "usage"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve repo and number
# ---------------------------------------------------------------------------

if ! im_parse_ref "$RAW_REF"; then
  im_error "Cannot parse issue ref: $RAW_REF" "invalid_ref"
  exit 1
fi

if [[ -n "$REPO_OVERRIDE" ]]; then
  IM_REPO="$REPO_OVERRIDE"
fi

if [[ -z "$IM_REPO" ]]; then
  if ! out=$(gh_with_timeout "$GH_REST_TIMEOUT" gh repo view --json nameWithOwner -q .nameWithOwner 2>&1); then
    im_error "Cannot resolve repo: $out" "repo_resolve_failed"
    exit 1
  fi
  IM_REPO="$out"
fi

if [[ -z "$IM_NUMBER" ]]; then
  im_error "No issue number in ref: $RAW_REF" "invalid_ref"
  exit 1
fi

REPO_OWNER="${IM_REPO%%/*}"
REPO_NAME="${IM_REPO##*/}"

# ---------------------------------------------------------------------------
# Fetch via REST (gh issue view)
# ---------------------------------------------------------------------------

GH_FIELDS="id,number,title,state,body,labels,url,createdAt,updatedAt"
[[ "$WITH_COMMENTS" -eq 1 ]] && GH_FIELDS="$GH_FIELDS,comments"

if ! out=$(gh_with_timeout "$GH_REST_TIMEOUT" gh issue view "$IM_NUMBER" -R "$IM_REPO" \
  --json "$GH_FIELDS" 2>&1); then
  im_error "$out" "gh_failed"
  exit 1
fi

# Remap: gh uses "id" for the GraphQL node id; expose as "node_id" for clarity.
result=$(printf '%s' "$out" | jq '{
  number:     .number,
  title:      .title,
  state:      .state,
  body:       .body,
  labels:     [.labels[] | {id: .id, name: .name, color: .color}],
  url:        .url,
  node_id:    .id,
  created_at: .createdAt,
  updated_at: .updatedAt
}
+ (if has("comments") then {comments: [.comments[] | {
    author:     (.author.login // null),
    created_at: .createdAt,
    body:       .body,
    edited:     .includesCreatedEdit,
    url:        .url
  }]} else {} end)')

printf '%s\n' "$result"
