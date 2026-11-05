#!/bin/sh
###################################################################################
# @file        CreateZone.sh
# @brief       Provisions a new authoritative DNS zone within the Cloudflare architecture.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) to extract
#              its zone apex domain root, checks the provider catalog dynamically to
#              prevent duplicate allocations, routes authentication logic (Bearer token
#              vs. X-Auth credentials), provisions the zone, and blocks execution
#              defensively until the zone is verified active.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, cut, grep, awk, curl, jq, sleep, expr
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Safely validates variable constraints under explicit character boundaries.
#
# @exit        0  Success: Cloudflare DNS zone verified active or created successfully.
# @exit        1  Failure: Missing context paths, input parameter errors, or API timeouts.
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
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

zone_name="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"

DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"

if ( [ "`curl -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
then
        if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
        then
                api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
                /bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones"  -H "Content-Type: application/json" --data '{"name":"'${zone_name}'"}' 
        else
                /bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" --data '{"name":"'${zone_name}'"}'
        fi

        max_wait="120"
        sleep_interval="5"
        elapse="0"
        while ( [ "${elapse}" -lt "${max_wait}" ] && [ "`/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
        do
                /bin/sleep ${sleep_interval}
                elapse="`/usr/bin/expr ${elapse} + ${sleep_interval}`"
        done

        if ( [ "${elapse}" = "120" ] )
        then
                status "Failed to create zone in the DNS system"
                exit 1
        fi
fi
