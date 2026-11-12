#!/bin/sh
###################################################################################
# @file        create_zone.sh
# @brief       Provisions a new authoritative master DNS zone with the cloud provider via CLI.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script validates the target domain parameter, exports the required
#              infrastructure authentication tokens, checks the provider catalog via
#              linode-cli to prevent duplicate allocation states, and issues a JSON
#              creation payload to instantiate the master zone schema if missing.
#
# @param       $1  [Required] The target domain URL (e.g., "domain.com" or "://domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, jq, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate
#                executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Ensures the CLI authorization token environment variable is cleared immediately post-run.
#
# @exit        0  Success: Master DNS zone verified active or created successfully.
# @exit        *  Failure: Missing arguments, missing framework layouts, or bubbling
#                 exit codes generated directly by the underlying cloud execution client.
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

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

if [ -z "${1}" ]
then
        status "Error: Domain URL parameter is required."
        status "Usage: $0 <domain_url>"
        exit 1
fi

domain_url="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"

if [ -z "${TOKEN}" ] || [ -z "${DNS_USERNAME}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN or DNS_USERNAME)."
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
domain_json="$(/usr/local/bin/linode-cli --no-defaults --json domains list)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        unset LINODE_CLI_TOKEN
        status "Error: linode-cli domains list failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

# linode-cli --json returns a top-level array of domain objects
domain_id="$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain == $dom) | .id // empty')"

if [ -z "${domain_id}" ]
then
        status "Domain zone '${domain_url}' not found in catalog. Provisioning master zone layout..."

        json_payload="$(/bin/cat <<EOF
{
  "type": "master",
  "domain": "${domain_url}",
  "soa_email": "${DNS_USERNAME}"
}
EOF
)"

set +e
/usr/local/bin/linode-cli --no-defaults --json domains create "${json_payload}"
create_exit_code="$?"
set -e

        # Unset token instantly to maintain high security-isolation states
        unset LINODE_CLI_TOKEN

        if [ "${create_exit_code}" -ne 0 ]
        then
                status "Error: linode-cli domains create failed with exit code ${create_exit_code}." >&2
                exit "${create_exit_code}"
        fi

        status "Success: DNS master zone initialized cleanly for domain ${domain_url}."
fi

unset LINODE_CLI_TOKEN

exit 0


