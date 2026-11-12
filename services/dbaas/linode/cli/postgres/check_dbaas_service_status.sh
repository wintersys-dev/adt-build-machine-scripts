#!/bin/sh
###################################################################################
# @file        check_dbaas_service_status.sh
# @brief       Monitors cloud DBaaS instance orchestration status using the Linode CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script utilizes the native provider CLI binary tool to pull live
#              database deployment configurations, targets cluster instances by unique
#              ecosystem labels via jq, monitors active runtime states, handles API
#              fault errors, and shuts down securely after execution timeouts.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, linode-cli, jq, expr, sleep
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
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

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Polling status verification transaction track
while true 
do
        # Query platform configurations using explicit binary paths and parameters isolation tracking
        set +e
        cli_output="$([ -x /usr/local/bin/linode-cli ] && /usr/local/bin/linode-cli databases postgresql-list --json 2>/dev/null || /bin/echo "")"
        set -e

        db_status=""
        if [ -n "${cli_output}" ]
        then
                db_status="$(/bin/echo "${cli_output}" | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label == $lbl).status // empty')"
        fi

        if [ -z "${db_status}" ]
        then
                status "Database '${label}' not found or API error. Retrying..."
        elif [ "${db_status}" = "active" ]
        then
                status "Database is ready and active!"
                unset LINODE_CLI_TOKEN
                break
        elif [ "${db_status}" = "failed" ] || [ "${db_status}" = "error" ]
        then
                status "Database deployment failed with status: ${db_status}"
                unset LINODE_CLI_TOKEN
                exit 1
        else
                status "Current status: '${db_status}' (Attempt ${attempt}/${max_attempts})..."
        fi

        # Assess time boundary violations
        if [ "${attempt}" -ge "${max_attempts}" ]
        then
                total_wait_seconds="$(/usr/bin/expr "${max_attempts}" \* "${sleep_interval}")"
                status "Timed out waiting for database to become active after ${total_wait_seconds} seconds."
                unset LINODE_CLI_TOKEN
                exit 1
        fi

        # Increment tracking variables and sleep safely
        attempt="$(/usr/bin/expr "${attempt}" + 1)"
        /bin/sleep "${sleep_interval}"
done
unset LINODE_CLI_TOKEN
exit 0
