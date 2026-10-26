BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"


out_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_output_stream.log"
err_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/logs/build_error_stream.err"

script_name="${0##*/}"
message="${1}"

# 1. Print clean message to screen AND append to the regular logfile
/bin/echo "${message}" | /usr/bin/tee -a "${out_file}"

# 2. Print tagged message to standard error stream AND append to error log
/bin/echo "${script_name}: ${message}" | /usr/bin/tee -a "${err_file}" >&2

