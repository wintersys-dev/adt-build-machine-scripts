#!/bin/sh
###################################################################################
# @file        CheckDBaaSServerStatus.sh
# @brief       Monitors cloud DBaaS instance orchestration status until active.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script connects to the Linode v4 Managed Database API via piped 
#              authorization tokens, filters cluster instances by custom ecosystem 
#              labels, tracks processing states sequentially, handles API error spikes 
#              defensively, and times out safely using tracking boundaries.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, curl, jq, expr, sleep
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Robustly quotes all variable substitutions to trap space-injection faults.
#
# @exit        0  Success: Target database cluster verified in an active, running state.
# @exit        1  Failure: Missing context paths, explicit platform failures, or time-outs.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Framework deployment variables extraction using secure subshells
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract specific database identifier string cleanly
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"

# Configure standard polling loop limits safely
max_attempts=50
sleep_interval=20
attempt=1

status "Waiting for database '${label}' to become active..."

# Polling status verification transaction track
while true 
do
        # Safely query provider endpoints with hidden piped streams to prevent token leaks
        db_status="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/postgresql/instances" | /usr/bin/jq -r --arg lbl "${label}" '.data[] | select(.label == $lbl).status')"

        if [ -z "${db_status}" ]
        then
                status "Database '${label}' not found or API error. Retrying..."
        elif [ "${db_status}" = "active" ]
        then
                status "Database is ready and active!"
                break
        elif [ "${db_status}" = "failed" ] || [ "${db_status}" = "error" ]
        then
                status "Database deployment failed with status: ${db_status}"
                exit 1
        else
                status "Current status: '${db_status}' (Attempt ${attempt}/${max_attempts})..."
        fi

        # Assess time boundary violations
        if [ "${attempt}" -ge "${max_attempts}" ]
        then
                total_wait_seconds="$(/usr/bin/expr "${max_attempts}" \* "${sleep_interval}")"
                status "Timed out waiting for database to become active after ${total_wait_seconds} seconds."
                exit 1
        fi

        # Increment tracking variables and sleep safely
        attempt="$(/usr/bin/expr "${attempt}" + 1)"
        /bin/sleep "${sleep_interval}"
done

exit 0
