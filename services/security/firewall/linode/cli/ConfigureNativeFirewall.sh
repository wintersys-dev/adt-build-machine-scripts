#!/bin/sh
#######################################################################################################
# @file        ConfigureNativeFirewall.sh
# @brief       Manages the lifecycle of a Linode Cloud Firewall by locating or creating it, flushing existing configurations, and applying a JSON-specified inbound ruleset.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
# @details     This script queries the Linode API to find a firewall matching a composite label ('firewall_name' combined with a dynamically loaded build identifier). 
#              If the firewall does not exist, it provisions a new one with a default drop-all inbound policy. 
#              It then flushes any pre-existing configurations before injecting the fresh inbound ruleset provided via the arguments.
# @param       1 (firewall_name) The base descriptive label used to identify or create the firewall.
# @param       2 (ruleset)       A JSON string representing the array of inbound security rules to be applied.
# @env         TOKEN             The Linode API personal access token required for authenticating requests.
# @env         BUILD_IDENTIFIER  A unique identifier appended to the firewall label to distinguish between build environments.
# @exit        0                 Success. The firewall was located or created, and the updated rules were applied.
# @exit        1                 Failure. Occurs if the firewall creation fails, rule updates fail, or the ruleset payload is invalid.
#######################################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x
set -e

firewall_name="${1}"
ruleset="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"

export LINODE_CLI_TOKEN="${TOKEN}"

firewall_id="`/usr/local/bin/linode-cli --json firewalls list | /usr/bin/jq -r '.[] | select (.label | contains ("'${firewall_name}'")) |  select (.label | endswith ("'-${BUILD_IDENTIFIER}'")).id'`"

if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
    status "Unable to list firewalls"
    exit 1
fi

if ( [ "${firewall_id}" = "" ] )
then
        firewall_id="`/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP   --rules.outbound_policy ACCEPT | /usr/bin/jq -r '.[].id'`"
       
		if ( [ "$?" != "0" ] )
        then
			unset LINODE_CLI_TOKEN
            status "Unable to create firewall"
            exit 1
        fi   
else
        /usr/local/bin/linode-cli firewalls rules-update --inbound '[]' --outbound '[]' --inbound_policy DROP --outbound_policy ACCEPT ${firewall_id}
        if ( [ "$?" != "0" ] )
        then
			unset LINODE_CLI_TOKEN
            status "Unable to update firewall rules"
            exit 1
        fi   
fi

/usr/local/bin/linode-cli firewalls rules-update --inbound ${ruleset} ${firewall_id}

if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
    status "Unable to update firewall rules"
    exit 1
fi  

unset LINODE_CLI_TOKEN
/bin/echo "ADT_FIREWALL_ID:${firewall_id}"

