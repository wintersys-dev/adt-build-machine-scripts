#!/bin/sh
###################################################################################
# @file        ObtainDBaaSCertCli.sh
# @brief       Retrieves and validates the SSL CA Certificate for a Linode Managed Database via CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script utilizes the native provider CLI binary tool to retrieve the
#              Base64 encoded SSL CA certificate for a targeted database instance ID,
#              decodes it safely, and leverages OpenSSL validation parameters to
#              manually inspect path properties and certificate validity states.
#
# @param       $1  [Required] The unique platform identifier ID of the active database instance.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, linode-cli, jq, base64, openssl, mkdir, rm, mv
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#              - Robustly quotes all variable substitutions to trap space-injection faults.
#              - Prevents terminal process leak vulnerabilities by using clean temporary stream files.
#
# @exit        0  Success: Target database certificate successfully obtained, written, and verified.
# @exit        1  Failure: Missing arguments, CLI errors, or broken/expired cert parameters.
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
        status "Error: Database ID parameter is required."
        status "Usage: $0 <database_id>"
        exit 1
fi

database_id="${1}"

# Framework deployment variables extraction using secure subshells
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Establish clean targeting paths
runtime_dest="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
cert_target="${runtime_dest}/DBaaS_CERT"

# Verify localized ecosystem routing directories exist
if [ ! -d "${runtime_dest}" ]
then
        /bin/mkdir -p "${runtime_dest}"
fi

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Fetch payload parameters safely while using manual intercept hooks to catch runtime exceptions
set +e
cli_output="$("/usr/local/bin/linode-cli" databases mysql-ssl-cert "${database_id}" --no-headers --no-defaults --json 2>/dev/null)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${cli_output}" ]
then
        status "Failed to query cluster certificate catalog or CLI runtime error occurred."
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Parse and decode certificate stream directly into a safe temporary file
set +e
/bin/echo "${cli_output}" | /usr/bin/jq -r '.[].ca_certificate // empty' | /bin/base64 --decode > "${cert_target}.tmp" 2>/dev/null
parse_code="$?"
set -e

if [ "${parse_code}" -ne 0 ] || [ ! -s "${cert_target}.tmp" ]
then
        status "Failed to parse or decode the SSL CA certificate matrix payload."
        /bin/rm -f "${cert_target}.tmp"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Move file safely into place out of the staging context
/bin/mv -f "${cert_target}.tmp" "${cert_target}"

# Assess certificate cryptographic validity properties explicitly
set +e
/usr/bin/openssl x509 -in "${cert_target}" -checkend 0 -noout >/dev/null 2>&1
validation_code="$?"
set -e

if [ "${validation_code}" -ne 0 ]
then
        status "DBaaS certificate not present, truncated, or invalid (OpenSSL verification check failure)."
        /bin/rm -f "${cert_target}"
        unset LINODE_CLI_TOKEN
        exit 1
else 
        status "DBaaS certificate present and valid...OK to proceed"
fi

unset LINODE_CLI_TOKEN
exit 0


