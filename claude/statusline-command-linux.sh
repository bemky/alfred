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
  reset_epoch=$(TZ=UTC date -d "$clean" "+%s" 2>/dev/null)
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
  epoch=$(TZ=UTC date -d "$clean" "+%s" 2>/dev/null)
  if [ -z "$epoch" ]; then return; fi
  date -d "@$epoch" "+%b %-d"
}

# --- weekday_remaining_pct: percent of remaining work hours (9am-5pm local, weekdays) in the current month ---
weekday_remaining_pct() {
  y=$(date +%Y)
  m=$(date +%-m)
  d=$(date +%-d)
  hour=$(date +%-H)
  min=$(date +%-M)

  now_min=$(( hour*60 + min ))
  work_start=$((9*60))
  work_end=$((17*60))
  if [ "$now_min" -le "$work_start" ]; then
    today_remaining_min=$((work_end - work_start))
  elif [ "$now_min" -ge "$work_end" ]; then
    today_remaining_min=0
  else
    today_remaining_min=$((work_end - now_min))
  fi

  case $m in
    1|3|5|7|8|10|12) last_day=31 ;;
    4|6|9|11) last_day=30 ;;
    2)
      if [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; then
        last_day=29
      else
        last_day=28
      fi
      ;;
  esac

  # Sakamoto's algorithm month offsets, indexed by month 1-12
  set -- 0 3 2 5 0 3 5 1 4 6 2 4
  i=1
  t=0
  for off in "$@"; do
    if [ "$i" -eq "$m" ]; then t=$off; break; fi
    i=$((i+1))
  done

  yy=$y
  if [ "$m" -lt 3 ]; then yy=$((y-1)); fi

  total_min=0
  remaining_min=0
  n=1
  while [ "$n" -le "$last_day" ]; do
    dow=$(( (yy + yy/4 - yy/100 + yy/400 + t + n) % 7 ))
    if [ "$dow" -ne 0 ] && [ "$dow" -ne 6 ]; then
      total_min=$((total_min + 480))
      if [ "$n" -gt "$d" ]; then
        remaining_min=$((remaining_min + 480))
      elif [ "$n" -eq "$d" ]; then
        remaining_min=$((remaining_min + today_remaining_min))
      fi
    fi
    n=$((n+1))
  done

  if [ "$total_min" -gt 0 ]; then
    used_min=$((total_min - remaining_min))
    echo $(( used_min * 100 / total_min ))
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
printf "\033[38;5;208m\033[1m%s\033[22m\033[0m" "$model"
printf "\033[90m | \033[0m"
printf "\033[1m\033[38;2;76;208;222m%s\033[22m\033[0m" "$dir_name"
if [ -n "$branch" ]; then
  printf "%b" "$SEP"
  printf "\033[1m\033[38;2;192;103;222m%s\033[22m\033[0m" "$branch"
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
  wd_pct=$(weekday_remaining_pct)
  if [ -n "$wd_pct" ]; then
    if [ -n "$cc_pct" ] || [ -n "$mo_pct" ]; then printf "%b" "$SEP"; fi
    printf "\033[38;2;156;162;175mmo passed %%%s\033[0m" "$wd_pct"
    printf " \033[2m\033[38;2;156;162;175m(9-5 M-F)\033[0m"
  fi
fi
if [ -n "$ctx_str" ]; then
  printf "\033[90m | \033[0m"
  printf "\033[38;2;156;162;175mctx %s\033[0m" "$ctx_str"
  [ -n "$ctx_tokens_str" ] && printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$ctx_tokens_str"
fi