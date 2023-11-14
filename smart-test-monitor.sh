#!/bin/sh
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Must be run as root" >&2
  exit 2
fi

if [ $# -eq 0 ]; then
  echo "Must specificy at least 1 disk."
  exit 1
fi

# How many seconds to wait before polling smartctl to refresh progress
SMART_PROGRESS_REFRESH_RATE=600

# How many seconds to sleep before updating the remaining time before refresh
SCRIPT_REFRESH_RATE=1

FULL_BAR="▰"
EMPTY_BAR="▱"

print_progress_bar() {
  # $1: percent
  FULL_BARs=$((${1}/100+1))
  printf "["
  for i in $(seq 0 9); do
    if [ "$((i*10))" -lt "$1" ]; then
      printf "%s" "${FULL_BAR}"
    else
      printf "%s" "${EMPTY_BAR}"
    fi
  done
  printf "]"
}

ensure_dev_dir() {
  printf "%s" "${1}" | grep "^/dev/" > /dev/null 2>&1
  if [ "$?" -eq 1 ]; then
    printf "/dev/%s" "${1}"
  else
    printf "${1}"
  fi
}

refresh_header() {
  tput cup 0 0
  seconds_remaining="$((SMART_PROGRESS_REFRESH_RATE-REFRESH_TIME))"
  min=$((seconds_remaining/60))
  sec=$((seconds_remaining-min*60))
  printf '+------------------------------------------------------------------------------------------+\n'
  printf " SMART Test Progress Monitor - "
  if [ "${seconds_remaining}" -le 0 ]; then
    printf "Refeeshing...\n"
  else
    printf "Refresh in %sm %ss\n" "${min}" "${sec}"
  fi
  printf '+------------------------------------------------------------------------------------------+\n'
}

refresh() {
  disk_num=0
  for disk_arg in $@; do
    disk="$(ensure_dev_dir ${disk_arg})"
    disk_num=$((disk_num+1))
    smart_result="$(smartctl -a "${disk}")"

    if [ $? -eq 2 ]; then
      printf "Invalid disk: %s\n" "${disk}"
      exit 2
    elif [ $? -eq 0 ]; then
      printf "Error handling: %s (Error code: %s)\n" "${disk}" "$?"
      exit $?
    fi

    printf "%s" "${smart_result}" | grep "Transport protocol:" | grep "SAS" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
      printf "%s) %s is not a SAS disk. Skipping..." "${disk_num}" "${disk}"
      continue
    fi

    percent_remaining="$(printf "%s" "${smart_result}" | grep "remaining" | grep -o "[0-9]*%" | sed "s/%//g")"
    percent_complete="$((100-percent_remaining))"
    est_total_min="$(printf "%s" "${smart_result}" | grep -o "\[[0-9. ]* minutes\]" | awk '{gsub(/\[|\]/, ""); print $1}' | grep -o "^[0-9]*")"
    est_total_hrs="$((est_total_min/60))"
    est_percent_elapsed="$((100-${percent_remaining}))"

    est_elapsed_min="$((est_total_min*percent_complete/100))"
    est_elapsed_hrs="$((est_elapsed_min/60))"

    est_min_remaining="$((est_total_min*percent_remaining/100))"
    est_hrs_remaining="$((est_min_remaining/60))"

    tput el

    if [ "${est_total_min}" -le 120 ]; then
      remaining="${est_min_remaining}m"
    else
      remaining="${est_hrs_remaining}h"
    fi

    if [ "${est_elapsed_min}" -le 120 ]; then
      elapsed="${est_elapsed_min}m"
    else
      elapsed="${est_elapsed_hrs}h"
    fi

    if [ "${est_total_min}" -le 120 ]; then
      total="${est_total_min}m"
    else
      total="${est_total_hrs}h"
    fi

    printf '%s) %s %s[%s] %s / %s (%s remaining)\n' \
      "${disk_num}" \
      "${disk}" \
      "$(print_progress_bar "$((100-percent_remaining))")" \
      "${percent_complete}%" \
      "${elapsed}" \
      "${total}" \
      "${remaining}"

  done
}

main() {
  clear
  REFRESH_TIME="${SMART_PROGRESS_REFRESH_RATE}"
  while : ; do
    refresh_header
    if [ "${REFRESH_TIME}" -ge "${SMART_PROGRESS_REFRESH_RATE}" ]; then
      REFRESH_TIME=0
      refresh $@
    fi
    sleep "${SCRIPT_REFRESH_RATE}"
    REFRESH_TIME="$((REFRESH_TIME+SCRIPT_REFRESH_RATE))"
  done
}

# Entrypoint
main $@
