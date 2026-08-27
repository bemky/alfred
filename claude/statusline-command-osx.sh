#!/bin/sh
input=$(cat)

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // ""')

# --- folder ---
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_name=$(basename "$dir")

# --- git branch ---
branch=""
if [ -d "${dir}/.git" ] || git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
fi

# --- usage stats from cache (see fetch-usage.sh for format) ---
CACHE_FILE="/tmp/.claude_usage_cache_$(basename "$CONFIG_DIR")"
mode=""
five_h=""
seven_d=""
five_h_reset=""
seven_d_reset=""
cc_pct=""
cc_used=""
cc_limit=""
cc_expires=""
mo_pct=""
mo_used=""
mo_limit=""
mo_reset=""

if [ -f "$CACHE_FILE" ]; then
  mode=$(sed -n '1p' "$CACHE_FILE")
fi
case "$mode" in
  subscription)
    five_h=$(sed -n '2p' "$CACHE_FILE")
    seven_d=$(sed -n '3p' "$CACHE_FILE")
    five_h_reset=$(sed -n '4p' "$CACHE_FILE")
    seven_d_reset=$(sed -n '5p' "$CACHE_FILE")
    ;;
  monthly)
    cc_pct=$(sed -n '2p' "$CACHE_FILE")
    cc_used=$(sed -n '3p' "$CACHE_FILE")
    cc_limit=$(sed -n '4p' "$CACHE_FILE")
    cc_expires=$(sed -n '5p' "$CACHE_FILE")
    mo_pct=$(sed -n '6p' "$CACHE_FILE")
    mo_used=$(sed -n '7p' "$CACHE_FILE")
    mo_limit=$(sed -n '8p' "$CACHE_FILE")
    mo_reset=$(sed -n '9p' "$CACHE_FILE")
    ;;
  *)
    mode=""
    bash "$CONFIG_DIR/fetch-usage.sh" > /dev/null 2>&1 &
    ;;
esac

# --- compute_delta: given a raw ISO timestamp, returns human-readable time until reset ---
compute_delta() {
  clean=$(echo "$1" | sed 's/\.[0-9]*//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//' | sed 's/Z$//')
  if date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" >/dev/null 2>&1; then
    reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null)
  else
    reset_epoch=$(date -u -d "$clean" "+%s" 2>/dev/null)
  fi
  if [ -z "$reset_epoch" ]; then return; fi
  now_epoch=$(date -u "+%s")
  diff=$(( reset_epoch - now_epoch ))
  if [ "$diff" -le 0 ]; then echo "now"; return; fi
  days=$(( diff / 86400 ))
  hours=$(( (diff % 86400) / 3600 ))
  minutes=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d ${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h ${minutes}m"
  else
    echo "${minutes}m"
  fi
}

# --- format_month_day: given a raw ISO timestamp, returns e.g. "Sep 13" in local time ---
format_month_day() {
  clean=$(echo "$1" | sed 's/\.[0-9]*//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//' | sed 's/Z$//')
  if date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" >/dev/null 2>&1; then
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null)
  else
    epoch=$(date -u -d "$clean" "+%s" 2>/dev/null)
  fi
  if [ -z "$epoch" ]; then return; fi
  if date -r "$epoch" "+%b %-d" >/dev/null 2>&1; then
    date -r "$epoch" "+%b %-d"
  else
    date -d "@$epoch" "+%b %-d"
  fi
}

# --- context window ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_str=""
ctx_tokens_str=""
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  ctx_str="${used_int}%"
  ctx_used=$(echo "$input" | jq -r '(.context_window.current_usage.cache_read_input_tokens + .context_window.current_usage.cache_creation_input_tokens + .context_window.current_usage.input_tokens + .context_window.current_usage.output_tokens) // empty' 2>/dev/null)
  ctx_total=$(echo "$input" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)
  if [ -n "$ctx_used" ] && [ -n "$ctx_total" ]; then
    ctx_used_k=$(( ctx_used / 1000 ))
    ctx_total_k=$(( ctx_total / 1000 ))
    ctx_tokens_str="${ctx_used_k}k/${ctx_total_k}k"
  fi
fi

# --- assemble output ---
# line 1: model | folder • branch
# line 2: usage | ctx
SEP="\033[90m • \033[0m"

# line 1
printf "\033[38;5;208m%s\033[0m" "$model"
printf "\033[90m | \033[0m"
printf "\033[38;2;76;208;222m%s\033[0m" "$dir_name"
if [ -n "$branch" ]; then
  printf "%b" "$SEP"
  printf "\033[38;2;192;103;222m%s\033[0m" "$branch"
fi

# line 2
printf "\n"
if [ -n "$five_h" ]; then
  printf "\033[38;2;156;162;175m5h %s%%\033[0m" "$five_h"
  if [ -n "$five_h_reset" ]; then
    delta=$(compute_delta "$five_h_reset")
    [ -n "$delta" ] && printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$delta"
  fi
fi
if [ -n "$seven_d" ]; then
  [ -n "$five_h" ] && printf "%b" "$SEP"
  printf "\033[38;2;156;162;175m7d %s%%\033[0m" "$seven_d"
  if [ -n "$seven_d_reset" ]; then
    delta=$(compute_delta "$seven_d_reset")
    [ -n "$delta" ] && printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$delta"
  fi
fi
if [ "$mode" = "monthly" ]; then
  if [ -n "$cc_pct" ]; then
    printf "\033[38;2;156;162;175mcc %s%%\033[0m" "$cc_pct"
    printf " \033[2m\033[38;2;156;162;175m(\$%s/\$%s" "$cc_used" "$cc_limit"
    if [ -n "$cc_expires" ]; then
      expires_label=$(format_month_day "$cc_expires")
      [ -n "$expires_label" ] && printf " exp %s" "$expires_label"
    fi
    printf ")\033[0m"
  fi
  if [ -n "$mo_pct" ]; then
    [ -n "$cc_pct" ] && printf "%b" "$SEP"
    printf "\033[38;2;156;162;175mmo %s%%\033[0m" "$mo_pct"
    printf " \033[2m\033[38;2;156;162;175m(\$%s/\$%s" "$mo_used" "$mo_limit"
    if [ -n "$mo_reset" ]; then
      reset_label=$(format_month_day "$mo_reset")
      [ -n "$reset_label" ] && printf " %s" "$reset_label"
    fi
    printf ")\033[0m"
  fi
fi
if [ -n "$ctx_str" ]; then
  printf "\033[90m | \033[0m"
  printf "\033[38;2;156;162;175mctx %s\033[0m" "$ctx_str"
  [ -n "$ctx_tokens_str" ] && printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$ctx_tokens_str"
fi