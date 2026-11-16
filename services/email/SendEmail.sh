#!/bin/sh
#: Name:        SendEmail.sh
#: Purpose:     Dispatches email notifications using the configured email utility in software.dat.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       SendEmail.sh "<subject>" "<message>" "<level>" ["<to_address>"] ["<authentication>"]
#:              SendEmail.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Email subject line
#:   $2         [Required] Email body message
#:   $3         [Required] Notification severity level (e.g. INFO, ERROR, MANDATORY)
#:   $4         [Optional] Recipient email address or alias (defaults to "system")
#:   $5         [Optional] Authentication flag (pass "AUTHENTICATION" to omit machine IP prefix)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetBuildMachineIP.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, awk
#:
#: Exit Codes:
#:   0          Email dispatched successfully or suppressed by notification level policy
#:   1          Missing required parameters, missing config files, or underlying email utility failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Minimum of 3 arguments required."
        status "Usage: $0 <subject> <message> <level> [to_address] [authentication]"
        exit 1
fi

subject="${1}"
message="${2}"
level="${3}"
to_address="${4}"
authentication="${5}"

# Prefix message with the build machine IP address for standard operational alerts
if { [ "${level}" = "ERROR" ] || [ "${level}" = "INFO" ] || [ "${level}" = "MANDATORY" ]; } && [ "${authentication}" != "AUTHENTICATION" ]
then
        ip_address="$("${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh")"
        message="MESSAGE RELATED TO MACHINE WITH IP ADDRESS: ${ip_address}: ${message}"
fi

# Check notification level policy and exit silently if non-error messages are suppressed
notification_level="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" EMAIL_NOTIFICATION_LEVEL)"

if [ "${level}" != "MANDATORY" ] && [ "${notification_level}" = "ERROR" ] && [ "${level}" != "ERROR" ]
then
        exit 0
fi

# Verify software configuration file exists and resolve the active email utility
software_config="${BUILD_HOME}/configuration/software.dat"

if [ ! -r "${software_config}" ]
then
        status "Error: Software configuration file missing or unreadable at ${software_config}"
        exit 1
fi

email_util="$(/usr/bin/grep '^EMAILUTIL:' "${software_config}" | /usr/bin/awk -F':' '{print $NF}')"

if [ -z "${email_util}" ]
then
        status "Error: EMAILUTIL is not configured in ${software_config}"
        exit 1
fi

# Apply defaults for optional recipient and content type parameters
if [ -z "${to_address}" ]
then
        to_address="system"
fi

if [ -z "${content_type}" ]
then
        content_type="default"
fi

# Verify provider email script exists and is executable before invoking
provider_script="${BUILD_HOME}/services/email/${email_util}/SendEmail.sh"

if [ ! -x "${provider_script}" ]
then
        status "Error: Email provider script missing or not executable at ${provider_script}"
        exit 1
fi

# Dispatch the email via the configured provider utility
if ! "${provider_script}" "${subject}" "${message}" "${to_address}" "${content_type}"
then
        status "Error: ${provider_script} failed to send email."
        exit 1
fi

exit 0

