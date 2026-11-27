#!/bin/sh
#: Name:        obtain_dbaas_cert.sh
#: Purpose:     Retrieves and validates the SSL CA certificate for a Linode MySQL DBaaS cluster via CLI.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.1
#:
#: Usage:       obtain_dbaas_cert.sh <database_id>
#:              obtain_dbaas_cert.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique Linode platform identifier ID of the active database instance.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, mkdir, mv, rm, linode-cli, jq, base64, openssl
#:
#: Exit Codes:
#:   0          Target database certificate successfully obtained, written, and verified
#:   1          Missing arguments, CLI errors, or broken/expired certificate
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

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that the required target database instance ID argument was provided
if [ -z "${1}" ]
then
        status "Error: Database ID parameter is required."
        status "Usage: $0 <database_id>"
        exit 1
fi

database_id="${1}"

# Retrieve active deployment identifiers and API token from active context
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (CLOUDHOST, BUILD_IDENTIFIER, or TOKEN)."
        exit 1
fi

# Define target runtime directory and output path for the decoded CA certificate
runtime_dest="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
cert_target="${runtime_dest}/DBaaS_CERT"

# Ensure the destination runtime directory exists
if [ ! -d "${runtime_dest}" ]
then
        /bin/mkdir -p "${runtime_dest}"
fi

# Resolve Linode API database family slug ('mysql' or 'postgresql') from Field 1
db_family="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $1}')"
case "${db_family}" in
        MySQL|mysql)
                db_type="mysql"
                ;;
        Postgres|PostgreSQL|postgres|postgresql)
                db_type="postgresql"
                ;;
        *)
                status "Error: Unsupported database family '${db_family}' in DATABASE_DBaaS_INSTALLATION_TYPE."
                exit 1
                ;;
esac

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        exit 1
fi

# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Fetch the SSL certificate JSON payload via linode-cli with errexit paused
set +e
cli_output="$(/usr/local/bin/linode-cli databases mysql-ssl-cert "${database_id}" --no-headers --no-defaults --json 2>/dev/null)"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ] || [ -z "${cli_output}" ]
then
        status "Failed to query cluster certificate catalog or CLI runtime error occurred."
        exit 1
fi

# Extract and Base64-decode the CA certificate into a staging file
set +e
/bin/echo "${cli_output}" | /usr/bin/jq -r '.[].ca_certificate // empty' | /bin/base64 --decode > "${cert_target}.tmp" 2>/dev/null
parse_code="$?"
set -e

if [ "${parse_code}" -ne 0 ] || [ ! -s "${cert_target}.tmp" ]
then
        status "Failed to parse or decode the SSL CA certificate matrix payload."
        /bin/rm -f "${cert_target}.tmp"
        exit 1
fi

# Atomically move the validated temporary certificate file into its final runtime path
/bin/mv -f "${cert_target}.tmp" "${cert_target}"

# Verify via OpenSSL that the certificate is structurally valid and not currently expired
set +e
/usr/bin/openssl x509 -in "${cert_target}" -checkend 0 -noout >/dev/null 2>&1
validation_code="$?"
set -e

if [ "${validation_code}" -ne 0 ]
then
        status "DBaaS certificate not present, truncated, or invalid (OpenSSL verification check failure)."
        /bin/rm -f "${cert_target}"
        exit 1
else
        status "DBaaS certificate present and valid...OK to proceed"
fi

exit 0




