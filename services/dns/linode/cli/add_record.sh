#!/bin/sh
###################################################################################
# @file        add_record.sh
# @brief       Provisions a new dynamic A-record entry within the DNS matrix via CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) into 
#              isolated sub-domain and zone apex properties, queries provider catalogs
#              using the Linode CLI under bounded token scopes, and maps transaction
#              payload parameters dynamically to create a new host tracking entry.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
# @param       $2  [Required] The target IPv4 address destination tracking node.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, cut, linode-cli, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS A-record successfully provisioned via CLI.
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
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Fully Qualified Domain Name and target IP parameters are required."
        status "Usage: $0 <fqdn> <target_ip>"
        exit 1
fi

# Parse localized networking components safely using modern subshells
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
ip="${2}"

# Extract authorized structural access keys safely
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

# Fetch active domain zone layouts securely with manual intercept hooks to catch runtime exceptions
set +e
cli_domain_json="$("/usr/local/bin/linode-cli" domains list --no-defaults --json 2>/dev/null)"
domain_exit_code="$?"
set -e

if [ "${domain_exit_code}" -ne 0 ] || [ -z "${cli_domain_json}" ]
then
        status "Failed to query CLI domain management catalog or tool runtime error occurred."
		unset LINODE_CLI_TOKEN
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${cli_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain | contains($dom)) | .id // empty')"

if [ -z "${domain_id}" ]
then
        status "Domain ID not found via CLI matching zone track string pattern: ${domain_url}"
		unset LINODE_CLI_TOKEN
        exit 1
fi

# Execute firewall access list network updates while manual trackers trap faults
set +e
"/usr/local/bin/linode-cli" domains records-create "${domain_id}" --type A --name "${sub_domain}" --target "${ip}" --ttl_sec 60 --no-defaults
record_exit_code="$?"
set -e

if [ "${record_exit_code}" -ne 0 ] 
then
        status "Failed to add DNS record for domain ${domain_url}, sub domain ${sub_domain} and ip address ${ip}"
		unset LINODE_CLI_TOKEN
        exit 1
fi

status "DNS record successfully added via CLI: ${sub_domain}.${domain_url} -> ${ip} [TTL: 60s]"
unset LINODE_CLI_TOKEN

exit 0
