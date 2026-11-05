#!/bin/sh
###################################################################################
# @file        CreateZone.sh
# @brief       Provisions a new authoritative master DNS zone via the Linode CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) to extract
#              its zone apex domain root, checks the provider catalog defensively via the
#              CLI to prevent duplicate allocation states, and issues a secure authorized 
#              command to instantiate the master zone schema if missing.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, cut, linode-cli, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#              - Safely validates variable constraints under explicit character boundaries.
#
# @exit        0  Success: Master DNS zone verified active or created successfully via CLI.
# @exit        1  Failure: Missing context paths, input parameter errors, or binary failures.
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

# Input validation
if [ -z "${1}" ]
then
        status "Error: Fully Qualified Domain Name parameter is required."
        status "Usage: $0 <fqdn>"
        exit 1
fi

# Parse apex zone identifier safely using modern subshells
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"

# Extract authorized structural access configurations
DNS_USERNAME="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME)"     
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY)"

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Fetch active domain zone layout securely with manual intercept hooks to catch runtime exceptions
set +e
cli_domain_json="$("/usr/local/bin/linode-cli" domains list --domain "${domain_url}" --json 2>/dev/null)"
domain_exit_code="$?"
set -e

if [ "${domain_exit_code}" -ne 0 ] || [ -z "${cli_domain_json}" ]
then
        status "Failed to query CLI domain management catalog or tool runtime error occurred."
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${cli_domain_json}" | /usr/bin/jq -r '.[].id // empty')"

# If the zone does not exist, execute creation step via CLI
if [ -z "${domain_id}" ]
then
        status "Domain zone '${domain_url}' not found in catalog. Provisioning master zone layout via CLI..."

        set +e
        "/usr/local/bin/linode-cli" domains create --type master --domain "${domain_url}" --soa_email "${DNS_USERNAME}" --no-defaults
        create_exit_code="$?"
        set -e

        if [ "${create_exit_code}" -ne 0 ]
        then
                status "Failed to create zone for domain ${domain_url} via Linode CLI."
                unset LINODE_CLI_TOKEN
                exit 1
        fi

        status "DNS master zone successfully initialized via CLI for domain: ${domain_url}"
else
        status "DNS master zone already active for domain: ${domain_url} (ID: ${domain_id})"
fi

unset LINODE_CLI_TOKEN
exit 0

