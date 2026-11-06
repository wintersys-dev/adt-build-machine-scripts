#!/bin/sh
###################################################################################
# @file        VerifiySelectedEngine.sh
# @brief       Validates chosen database engine compatibility against active cloud regions.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries the cloud provider managed database engines catalog,
#              extracts all verified running engine keys, maps them cleanly, and 
#              verifies the targeted deployment engine option defensively before 
#              allowing downstream infrastructure build operations to trigger.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, curl, jq, grep
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Avoids blind loop execution failures by splitting validation pipelines.
#
# @exit        0  Success: Target database engine successfully verified against cloud catalog.
# @exit        1  Failure: Missing configuration contexts, API errors, or unsupported engine.
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

# Extract specific engine identifier string cleanly from parsing matrix strings
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"

# Fetch active cloud database engine listings with manual intercept hooks to catch runtime exceptions
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/engines")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to obtain list of available engines (Network/Curl infrastructure execution error)."
        exit 1
fi

# Verify payload returns to protect against masked HTTP authentication errors
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // "Unknown API error parameters."')"
        status "Failed to obtain engine list. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Parse available running profiles defensively using parameters isolation tracking
available_engines="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.data[].id // empty')"

if [ -z "${available_engines}" ]
then
        status "Failed to parse available engines from the cloud management catalog metadata."
        exit 1
fi

# Confirm targeted deployment option exists within the extracted platform layout
set +e
/bin/echo "${available_engines}" | /bin/grep -q -w "${engine}"
match_code="$?"
set -e

if [ "${match_code}" -ne 0 ]
then
        status "The database engine you have selected (${engine}) is not available. Please correct and re-deploy."
        exit 1
fi

status "Database engine '${engine}' successfully verified against cloud catalog... OK to proceed."
exit 0
