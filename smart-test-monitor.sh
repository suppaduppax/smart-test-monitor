#!/bin/sh

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Must be run as root" >&2
  exit 2
fi

USAGE=\
"
./${0} [Options] <DISKS>

Options               Description
----------            ---------------
-b style              Set the progress bar style. The default style is 'normal'. 
                      Available styles are: normal, simple, large
-o                    Only run the script once and then exit without looping
-r SECONDS            Set the refresh interval between smartctl polls
-s SECONDS            Set the update interval of the internal script
"

# How many seconds to wait before polling smartctl to refresh progress
SMART_PROGRESS_REFRESH_RATE=600

# How many seconds to sleep before updating the remaining time before refresh
SCRIPT_REFRESH_RATE=1

# At how many minutes should time be displayd in minutes instead of hours (inclusive)
DISPLAY_MINUTES_THRESHOLD=59

FULL_BAR="▰"
EMPTY_BAR="▱"
RUN_ONCE=0

# parse options
while getopts 'or:s:b:' option; do
  case "${option}" in
    o)  readonly RUN_ONCE=1
        ;;
    r)  readonly SMART_PROGRESS_REFRESH_RATE="${OPTARG}"
        ;;
    s)  readonly SCRIPT_REFRESH_RATE="${OPTARG}"
        ;;
    b)  if [ "${OPTARG}" = "normal" ]; then
          FULL_BAR="▰"
          EMPTY_BAR="▱"
        elif [ "${OPTARG}" = "simple" ]; then
          FULL_BAR="="
          EMPTY_BAR="·"
        elif [ "${OPTARG}" = "large" ]; then
          FULL_BAR="▓"
          EMPTY_BAR="░"
        else
          printf "Illegal option for -b: '%s'. Available options are normal, simple, large \n"
          exit 2
        fi
        ;;
    :)  printf 'Missing argument for -%s\n' "${OPTARG}" >&2
        echo "${USAGE}" >&2
        exit 2
        ;;
   \?)  printf 'Illegal option: -%s\n' "${OPTARG}" >&2
        echo "${USAGE}" >&2
        exit 2
        ;;
  esac
done
shift $(( OPTIND - 1 ))

if [ -z "$1" ]; then
  echo "ERROR: Missing disk argument" >&2
  echo "${USAGE}" >&2
  exit 2
fi

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

run_once_wrapper() {
  if [ "${RUN_ONCE}" -eq 0 ]; then
    eval "$1"
  fi
}

refresh_header() {
  run_once_wrapper "tput cup 0 0"


  seconds_remaining="$((SMART_PROGRESS_REFRESH_RATE-REFRESH_TIME))"
  min=$((seconds_remaining/60))
  sec=$((seconds_remaining-min*60))
  printf '+------------------------------------------------------------------------------------------+\n'
  printf " SMART Test Progress Monitor - "
  if [ "${seconds_remaining}" -le 0 ]; then
    printf "Refreshing...                   \n"
  else
    printf "Refresh in "
    [ "${min}" -gt 0 ] && printf '%sm ' "${min}"
    printf '%ss              \n' "${sec}"
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
      printf "%s) %s is not a SAS disk. Skipping...\n" "${disk_num}" "${disk}"
      continue
    fi

    percent_remaining="$(printf "%s" "${smart_result}" | grep "remaining" | grep -o "[0-9]*%" | sed "s/%//g")"
    if [ -z "${percent_remaining}" ]; then
      printf '%s) %s - Cannot find any SMART test in progress. Either it is complete or was never started\n' \
      "${disk_num}" \
      "${disk}"
      continue
    fi

    percent_complete="$((100-percent_remaining))"
    est_total_min="$(printf "%s" "${smart_result}" | grep -o "\[[0-9. ]* minutes\]" | awk '{gsub(/\[|\]/, ""); print $1}' | grep -o "^[0-9]*")"
    est_total_hrs="$((est_total_min/60))"
    est_percent_elapsed="$((100-${percent_remaining}))"
    est_elapsed_min="$((est_total_min*percent_complete/100))"
    est_elapsed_hrs="$((est_elapsed_min/60))"
    est_min_remaining="$((est_total_min*percent_remaining/100))"
    est_hrs_remaining="$((est_min_remaining/60))"

    # clear the current line
    run_once_wrapper "tput el"

    if [ "${est_min_remaining}" -le "${DISPLAY_MINUTES_THRESHOLD}" ]; then
      remaining="${est_min_remaining}m"
    else
      remaining="${est_hrs_remaining}h"
    fi

    if [ "${est_elapsed_min}" -le "${DISPLAY_MINUTES_THRESHOLD}" ]; then
      elapsed="${est_elapsed_min}m"
    else
      elapsed="${est_elapsed_hrs}h"
    fi

    if [ "${est_total_min}" -le "${DISPLAY_MINUTES_THRESHOLD}" ]; then
      total="${est_total_min}m"
    else
      total="${est_total_hrs}h"
    fi

    printf '%s) %s %s[%s]' \
      "${disk_num}" \
      "${disk}" \
      "$(print_progress_bar "$((100-percent_remaining))")" \
      "${percent_complete}%" \

    if [ "${est_min_remaining}" -gt 0 ]; then
      printf ' %s / %s (%s remaining)\n' \
        "${elapsed}" \
        "${total}" \
        "${remaining}"
    else
      printf ' --- Complete! --- \n'
    fi
  done
}

main() {
  run_once_wrapper "clear"
  REFRESH_TIME="${SMART_PROGRESS_REFRESH_RATE}"
  while : ; do
    refresh_header
    if [ "${REFRESH_TIME}" -ge "${SMART_PROGRESS_REFRESH_RATE}" ]; then
      REFRESH_TIME=0
      refresh $@
      run_once_wrapper "refresh_header"
    fi

    if [ "${RUN_ONCE}" -ne 0 ]; then
      break
    fi

    sleep "${SCRIPT_REFRESH_RATE}"
    REFRESH_TIME="$((REFRESH_TIME+SCRIPT_REFRESH_RATE))"
  done
}

# Entrypoint
main $@
