#!/bin/sh

# Terminal colour strings
readonly RED='\033[0;31m'
readonly GRAY='\e[36m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'              # No Color


# Threshholds for power
readonly FAIL_POWER_ON_HOURS=70000
readonly FAIL_BYTES_WRITTEN=1000000 # need to verify this

errors=0

get_device_type() {
	result=$(printf '%s' "${1}" | grep "Transport protocol:" | awk '{print $3}' | tr -d '\n')
	[ -z "$result" ] && result=$(echo "${1}" | grep "ATA Version is:" | awk '{print $1}' | tr -d '\n')
	if [ -z "$result" ]; then
		echo "Cannot determine device type..."
		exit 1
	fi

	printf "${result}"
}

get_raw_value() {
  for last_value in $@; do true; done
	echo "${last_value}"
}

print_result() {
	raw_value="$(get_raw_value $@)"
	if [ "${raw_value}" -ne 0 ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ PASS ] ${NC}"
	fi

	printf "%3s %-22s = %3d ${NC}\n" "$1" "$2" "${raw_value}"
}

check_pass_sata() {
	for smart_num in $@; do
		smart_value="$(printf '%s' "${SMART_RESULT}" | grep "${smart_num}")"
		if [ ! -z "${smart_value}" ]; then
			print_result "${smart_value}"
		fi
	done
}

check_pass_sas() {
	read_errors=$(printf '%s' "${SMART_RESULT}" | grep "read: " | awk '{print $8}' | tr -d '\n')
	write_errors=$(printf '%s' "${SMART_RESULT}" | grep "write: " | awk '{print $8}' | tr -d '\n')
	verify_errors=$(printf '%s' "${SMART_RESULT}" | grep "verify: " | awk '{print $8}' | tr -d '\n')
	if [ "${read_errors}" -gt 0 ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ SUCCESS ] "
	fi
	printf "Read uncorrectable errors: %1s${NC}\n" "$read_errors"

	if [ "${write_errors}" -gt 0 ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ SUCCESS ] "
	fi
	printf "Write uncorrectable errors: %1s${NC}\n" "${write_errors}"

	if [ "${verify_errors}" -gt 0 ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ SUCCESS ] "
	fi
	printf "Verify uncorrectable errors: %1s${NC}\n" "${verify_errors}"

	power_on_hours=$(printf '%s' "${SMART_RESULT}" | grep "Accumulated power on time" | sed  's/:/ /g' | awk '{print $7}' | tr -d '\n')
	if [ "${power_on_hours}" -gt "${FAIL_POWER_ON_HOURS}" ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ SUCCESS ] "
	fi
	printf "Accumulated power on hours: %1s${NC}\n" "$power_on_hours"

	bytes_written_decimal=$(printf '%s' "${SMART_RESULT}" | grep 'write:' | awk '{print $7}')
	bytes_written=$(printf "%.0f" "${bytes_written_decimal}")
	if [ "${bytes_written}" -gt "${FAIL_BYTES_WRITTEN}" ]; then
		printf "${RED}[ FAIL ] "
		errors=$((errors+1))
	else
		printf "${GREEN}[ SUCCESS ] "
	fi
	printf "Bytes written: %1s${NC}\n" "$bytes_written"

}

check_dev() {
	for disk in "$@"; do
	if [ -z "$disk" ]; then
		echo "Must specify disk device ie /dev/da0"
		exit 1
	fi

  printf "%s" "${disk}" | grep "/dev/"
  [ "$?" -ne 0 ] && disk="/dev/${disk}"

	SMART_RESULT=$(smartctl -a "${disk}")
	printf "%s" "${SMART_RESULT}" | grep "$disk: Unable to detect device type" > /dev/null 2>&1

  if [ "$?" -eq 0 ]; then
		echo "Cannot find device: '$disk'"
		exit 1
	fi

	echo "------------------------------------------"
	echo "Checking SMART data for $disk"
	echo "------------------------------------------"

	check_pass_sata "5.*Reallocated_Sector_Ct" "184.*End-to-End_Error" "187.*Reported_Uncorrect" "188.*Command_Timeout" "197.*Current_Pending_Sector" "198.*Offline_Uncorrectable"

	done

	echo "------------------------------------------"
	echo "Completed with $errors errors!"
	echo "------------------------------------------"
}


#check_file() {
	for arg in $@; do
      src="${arg}"
    if printf '%s' "${arg}" | grep "/dev/" > /dev/null 2>&1; then
      echo "FOUND"
      SMART_RESULT="$(smartctl --all "${arg}")"
    else
      # first check if it exists in /dev/
      if [ -f "/dev/${arg}" ]; then
        SMART_RESULT="$(smartctl --all "/dev/${arg}")"
        src="/dev/${arg}"
      elif [ -f "${arg}" ]; then
        # source is not in /dev/ and is a file
        SMART_RESULT="$(cat "${arg}")"
  		else
        echo "Could not find file $file"
			  exit 1
		  fi
    fi

    device_type="$(get_device_type "${SMART_RESULT}")"
    if [ "$?" -ne 0 ]; then
      printf 'Error finding device type... skipping\n'
      continue
    fi

		echo "------------------------------------------"
		echo "Checking SMART data for ${src} (${device_type})"
		echo "------------------------------------------"

		if [ "${device_type}" = "SAS" ]; then
			check_pass_sas
		else
			check_pass_sata "5.*Reallocated_Sector_Ct" "184.*End-to-End_Error" "187.*Reported_Uncorrect" "188.*Command_Timeout" "197.*Current_Pending_Sector" "198.*Offline_Uncorrectable"
		fi
	done

	echo "------------------------------------------"
	echo "Completed with $errors errors!"
	echo "------------------------------------------"
#}

#	check_file $@

