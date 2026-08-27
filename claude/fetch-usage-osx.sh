#!/bin/sh
# Fetches Claude usage stats and writes them to /tmp/.claude_usage_cache.
# Cache format is line-based; line 1 is the mode.
#
# mode "subscription" (personal plan: 5h / 7d token limits):
#   Line 2: five_hour.utilization (integer %)
#   Line 3: seven_day.utilization (integer %)
#   Line 4: five_hour.resets_at (raw ISO string, e.g. 2026-02-26T12:59:59.997656+00:00)
#   Line 5: seven_day.resets_at (raw ISO string)
#
# mode "monthly" (work/enterprise login: dollar budgets; five_hour/seven_day are null):
#   Line 2: Claude Code + Cowork credit utilization (integer %)   [.cinder_cove — drawn first]
#   Line 3: credit used dollars (e.g. 847.13)
#   Line 4: credit limit dollars (e.g. 1000)
#   Line 5: credit expires_at (raw ISO string; one-time credit, not a monthly reset)
#   Line 6: monthly spend-limit utilization (integer %)   [.spend / .extra_usage]
#   Line 7: spend used dollars (e.g. 94.02)
#   Line 8: spend limit dollars (e.g. 1000)
#   Line 9: spend resets_at (raw ISO string) — DERIVED, not from the API: the spend
#           limit is monthly, so this is midnight UTC on the 1st of next month.
#   Either pool's lines may be blank if the API omits it.
#
# All output is suppressed; meant to be run in background.

CACHE_FILE="/tmp/.claude_usage_cache"

if command -v security >/dev/null 2>&1; then
  raw_creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
else
  raw_creds=$(cat "$HOME/.claude/.credentials.json" 2>/dev/null)
fi
if [ -z "$raw_creds" ]; then
  exit 0
fi

token=$(printf '%s' "$raw_creds" | grep -o 'sk-ant-oat01-[A-Za-z0-9_-]*' | head -1)
if [ -z "$token" ]; then
  exit 0
fi

usage_json=$(curl -s -m 10 \
  -H "accept: application/json" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "authorization: Bearer $token" \
  -H "user-agent: claude-code/2.1.11" \
  "https://api.anthropic.com/oauth/usage" 2>/dev/null)

if [ -z "$usage_json" ]; then
  exit 0
fi

five_h_raw=$(printf '%s' "$usage_json" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
seven_d_raw=$(printf '%s' "$usage_json" | jq -r '.seven_day.utilization // empty' 2>/dev/null)

if [ -n "$five_h_raw" ] && [ -n "$seven_d_raw" ]; then
  five_h=$(printf "%.0f" "$five_h_raw")
  seven_d=$(printf "%.0f" "$seven_d_raw")
  five_h_reset=$(printf '%s' "$usage_json" | jq -r '.five_hour.resets_at // ""' 2>/dev/null)
  seven_d_reset=$(printf '%s' "$usage_json" | jq -r '.seven_day.resets_at // ""' 2>/dev/null)
  printf 'subscription\n%s\n%s\n%s\n%s\n' "$five_h" "$seven_d" "$five_h_reset" "$seven_d_reset" > "$CACHE_FILE"
  exit 0
fi

cc_pct_raw=$(printf '%s' "$usage_json" | jq -r '.cinder_cove.utilization // empty' 2>/dev/null)
cc_used_raw=$(printf '%s' "$usage_json" | jq -r '.cinder_cove.used_dollars // empty' 2>/dev/null)
cc_limit=$(printf '%s' "$usage_json" | jq -r '.cinder_cove.limit_dollars // empty' 2>/dev/null)
cc_expires=$(printf '%s' "$usage_json" | jq -r '.cinder_cove.resets_at // ""' 2>/dev/null)

cc_pct=""
cc_used=""
if [ -n "$cc_pct_raw" ] && [ -n "$cc_used_raw" ] && [ -n "$cc_limit" ]; then
  cc_pct=$(printf "%.0f" "$cc_pct_raw")
  cc_used=$(printf "%.2f" "$cc_used_raw")
else
  cc_limit=""
  cc_expires=""
fi

mo_pct=""
mo_used=""
mo_limit=""
mo_reset=""
spend_enabled=$(printf '%s' "$usage_json" | jq -r '.spend.enabled // empty' 2>/dev/null)
if [ "$spend_enabled" = "true" ]; then
  mo_used_raw=$(printf '%s' "$usage_json" | jq -r '.spend.used | (.amount_minor / pow(10; .exponent)) // empty' 2>/dev/null)
  mo_limit=$(printf '%s' "$usage_json" | jq -r '.spend.limit | (.amount_minor / pow(10; .exponent)) | . * 100 | round / 100' 2>/dev/null)
  mo_pct_raw=$(printf '%s' "$usage_json" | jq -r '.extra_usage.utilization // .spend.percent // empty' 2>/dev/null)
  if [ -n "$mo_used_raw" ] && [ -n "$mo_limit" ] && [ -n "$mo_pct_raw" ]; then
    mo_pct=$(printf "%.0f" "$mo_pct_raw")
    mo_used=$(printf "%.2f" "$mo_used_raw")
    # Monthly budget: rolls over at midnight UTC on the 1st of next month.
    year=$(date -u "+%Y")
    month=$(date -u "+%m")
    if [ "$month" = "12" ]; then
      year=$(( year + 1 ))
      month=1
    else
      month=$(( ${month#0} + 1 ))
    fi
    mo_reset=$(printf '%04d-%02d-01T00:00:00+00:00' "$year" "$month")
  else
    mo_limit=""
  fi
fi

if [ -n "$cc_pct" ] || [ -n "$mo_pct" ]; then
  printf 'monthly\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$cc_pct" "$cc_used" "$cc_limit" "$cc_expires" \
    "$mo_pct" "$mo_used" "$mo_limit" "$mo_reset" > "$CACHE_FILE"
fi
