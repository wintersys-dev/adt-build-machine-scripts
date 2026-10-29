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

firewall_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/networking/firewalls" | jq -r --arg name "${firewall_name}" --arg build "-${BUILD_IDENTIFIER}" '.data[] | select(.label | contains($name)) | select(.label | endswith($build)).id')"

if [ "${firewall_id}" = "" ] 
then
        payload=$(jq -n --arg lbl "${firewall_name}-${BUILD_IDENTIFIER}" '{label: $lbl, rules: {inbound_policy: "DROP", outbound_policy: "ACCEPT"}}')
        firewall_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- curl -s -X POST 'https://api.linode.com/v4/networking/firewalls' --json "${payload}" | jq -r '.id')"

        if [ "$?" != "0" ] 
        then
                status "Unable to create firewall"
                exit 1        
        fi
else
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s  -X PUT -H 'Content-Type: application/json' -d '{"inbound": [], "outbound": [], "inbound_policy": "DROP", "outbound_policy": "ACCEPT"}' 'https://api.linode.com/v4/networking/firewalls/'${firewall_id}'/rules'
        if [ "$?" != "0" ] 
        then
                status "Unable to update firewall rules"
                exit 1        
        fi
fi              

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/networking/firewalls/${firewall_id}/rules" --json "$(jq -n --argjson rules "${ruleset}" '{inbound: $rules}')"
if [ "$?" != "0" ]   
then
        status "Unable to update firewall rules"
        exit 1          
fi                              

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
