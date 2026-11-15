#!/bin/sh
#: Name:        get_proxy_dns_ips.sh
#: Purpose:     Retrieves the active IPv4 proxy edge CIDR ranges list from Cloudflare.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       get_proxy_dns_ips.sh
#:              get_proxy_dns_ips.sh [-h|--help]
#:
#: Parameters:
#:   None       Queries Cloudflare's public IP range catalog endpoint.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, curl, jq, tr
#:
#: Exit Codes:
#:   0          Cloudflare IPv4 ranges successfully resolved and printed
#:   1          Missing configuration contexts or structural path faults
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries strictly to stderr so stdout remains clean CIDR output for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}
# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="cloudflare.com"
api_path="client/v4/ips"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Query Cloudflare's public IP ranges endpoint with errexit paused to allow fallback on failure
set +e
api_response="$(/usr/bin/curl -s -X GET "${endpoint}" -H "Content-Type: application/json")"
exit_code="$?"
set -e

all_proxy_dns_ips=""

# Extract and flatten the IPv4 CIDR array into a space-delimited list when the query succeeds
if [ "${exit_code}" -eq 0 ] && [ -n "${api_response}" ]
then
        if ! /bin/echo "${api_response}" | /usr/bin/jq -e '.success == true and .result.ipv4_cidrs' >/dev/null 2>&1
        then
                status "Warning: Cloudflare API endpoint returned error metadata. Invoking baseline fallback."
        else
                all_proxy_dns_ips="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.result.ipv4_cidrs[] // empty' | /usr/bin/tr '\n' ' ')"
        fi
fi

# Fall back to the static Cloudflare IPv4 CIDR list if the dynamic query failed or returned empty
if [ -z "${all_proxy_dns_ips}" ] || [ "${all_proxy_dns_ips}" = '""' ] || [ "${all_proxy_dns_ips}" = "null" ]
then
        all_proxy_dns_ips="103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 104.16.0.0/13 104.24.0.0/14 108.162.192.0/18 141.101.64.0/18 162.158.0.0/15 172.64.0.0/13 173.245.48.0/20 188.114.96.0/20 190.93.240.0/20 197.234.240.0/22 198.41.128.0/17 131.0.72.0/22 199.27.128.0/21"
fi

# Collapse duplicate whitespace and emit the space-separated IPv4 CIDR list to stdout
/bin/echo "${all_proxy_dns_ips}" | /usr/bin/tr -s ' '
exit 0

