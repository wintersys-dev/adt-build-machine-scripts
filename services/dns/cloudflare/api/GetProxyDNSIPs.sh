#!/bin/sh
###################################################################################
# @file        GetProxyDNSIPs.sh
# @brief       Retrieves the active IPv4 proxy edge networks list from Cloudflare.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries Cloudflare's public utility metadata endpoint to pull
#              the active list of proxy edge servers, falls back defensively onto an
#              authenticated hardcoded array list if the network drops, and echoes
#              a clean space-separated array definition string.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - external dependencies: cat, echo, curl, jq, tr
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Robustly quotes all variable conditions to resist expansion injection errors.
#
# @exit        0  Success: Cloudflare IPv4 ranges successfully resolved and printed.
# @exit        1  Failure: Missing configuration contexts or platform structural paths faults.
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

# Query Cloudflare public ranges catalog safely with manual intercept hooks to catch network drops
set +e
api_response="$(/usr/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/ips" -H "Content-Type: application/json")"
exit_code="$?"
set -e

all_proxy_dns_ips=""

# If the network execution succeeded, extract and reformat the dynamic IPv4 payload matrix array safely
if [ "${exit_code}" -eq 0 ] && [ -n "${api_response}" ]
then
        # Verify transaction success flags defensively before attempting formatting pipelines
        if ! /bin/echo "${api_response}" | /usr/bin/jq -e '.success == true and .result.ipv4_cidrs' >/dev/null 2>&1
        then
                status "Warning: Cloudflare API endpoint returned error metadata tracks. Invoking baseline fallback."
        else
                all_proxy_dns_ips="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.result.ipv4_cidrs[] // empty' | /usr/bin/tr '\n' ' ')"
        fi
fi

# Apply absolute hardcoded proxy definitions fallback if lookup parameters are empty or explicitly null
if [ -z "${all_proxy_dns_ips}" ] || [ "${all_proxy_dns_ips}" = '""' ] || [ "${all_proxy_dns_ips}" = "null" ]
then
        all_proxy_dns_ips="103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 104.16.0.0/13 104.24.0.0/14 108.162.192.0/18 141.101.64.0/18 162.158.0.0/15 172.64.0.0/13 173.245.48.0/20 188.114.96.0/20 190.93.240.0/20 197.234.240.0/22 198.41.128.0/17 131.0.72.0/22 199.27.128.0/21"
fi

# Clean trailing whitespace parameters and emit the finalized text data string safely
/bin/echo "${all_proxy_dns_ips}" | /usr/bin/tr -s ' '
exit 0

