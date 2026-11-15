#!/bin/sh
#: Name:        TerminateServer.sh
#: Purpose:     Gracefully shuts down and permanently deletes a Linode server by IP.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       TerminateServer.sh <server_ip>
#:              TerminateServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target IPv4 address of the instance to destroy.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetServerName.sh
#:   - ListServerIDs.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/{shutdown_instance,get_instance_status,delete_instance}.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, sleep, expr
#:
#: Exit Codes:
#:   0          Instance was successfully shut down and deleted
#:   1          Missing arguments, invalid config, no matching server, or deletion failure
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that the required target server IP address argument was provided
if [ -z "${1}" ]
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>"
        exit 1
fi

server_ip="${1}"

# Read software.dat and resolve the active orchestration tool (cli or api)
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/server/linode/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# Resolve the Linode server label from its IPv4 address
server_name="$("${BUILD_HOME}/services/server/linode/GetServerName.sh" "${server_ip}")"

if [ -n "${server_name}" ]
then
        # Translate the resolved server label into its numeric Linode instance ID
        server_id="$("${BUILD_HOME}/services/server/linode/ListServerIDs.sh" "${server_name}")"

        status "Initiating graceful shutdown for instance '${server_name}' (ID: ${server_id}, IP: ${server_ip})..."

        # Dispatch graceful shutdown request via the active orchestration wrapper
        "${BUILD_HOME}/services/server/linode/${orchestration_tool}/shutdown_instance.sh" "${server_id}"
        count="0"

        # Poll instance status every 10 seconds until offline or 21 attempts (3.5 minutes) elapse
        while true
        do
                current_status="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/get_instance_status.sh" "${server_id}")"
                if [ "${current_status}" = "offline" ] || [ "${count}" -ge 21 ]
                then
                        break
                fi

                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="$(/usr/bin/expr "${count}" + 1)"
        done

        status "Executing permanent deletion routine for instance ID: ${server_id}..."

        # Permanently delete the Linode instance once offline
        "${BUILD_HOME}/services/server/linode/${orchestration_tool}/delete_instance.sh" "${server_id}"
        status "Machine with id: ${server_id} and ip address ${server_ip} has been deleted"
else
        status "Error: No active server instance records matched IP tracking descriptor '${server_ip}'."
        exit 1
fi

exit 0

