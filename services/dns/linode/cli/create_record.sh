#!/bin/sh
#: Name:        create_record.sh
#: Purpose:     Creates a new DNS zone or DNS record under a Linode domain via linode-cli.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       create_record.sh <domain_id_or_zone> <json_payload>
#:              create_record.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Numerical identifier of the target DNS domain (or "zone" for new zone).
#:   $2         [Required] A valid JSON payload containing DNS zone or record details.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, jq, linode-cli
#:
#: Exit Codes:
#:   0          Target DNS domain zone or record created cleanly
#:   1          Missing arguments, layout faults, or context variable errors
#:   *          Bubbled exit code from linode-cli
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
#set -x
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

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Validate that both domain/zone sentinel and JSON payload arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Domain ID and JSON payload arguments are required."
        status "Usage: $0 <domain_id_or_zone> <json_payload>"
        exit 1
fi

domain_id="${1}"
json_payload="${2}"
# Reset positional parameters and unpack JSON key-value pairs into --key value CLI flags
set --

while IFS= read -r line
do
        [ -n "${line}" ] && set -- "$@" "${line}"
done <<EOF
$(printf '%s\n' "${json_payload}" | /usr/bin/jq -r 'to_entries[] | select(.value != null and .value != "") | "--\(.key)", (.value | tostring)')
EOF

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Export the API token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Execute master zone or DNS record creation via linode-cli with errexit paused
set +e
if [ "${domain_id}" = "zone" ]
then
        /usr/local/bin/linode-cli --no-defaults --json domains create "$@"
else
        /usr/local/bin/linode-cli --no-defaults --json domains records-create "${domain_id}" "$@"
fi
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

# Bubble up any non-zero exit code thrown by linode-cli
if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli domains operation failed with exit code ${exit_code}."
        exit "${exit_code}"
fi

exit 0

