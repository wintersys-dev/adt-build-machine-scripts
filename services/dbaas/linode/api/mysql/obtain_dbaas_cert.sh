#!/bin/sh
#: Name:        obtain_dbaas_cert.sh
#: Purpose:     Retrieves and validates the SSL CA certificate for a Linode MySQL DBaaS cluster.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
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
#:   - External binaries: cat, echo, grep, cut, mkdir, mv, rm, curl, jq, base64, openssl
#:
#: Exit Codes:
#:   0          Target database certificate successfully obtained, written, and verified
#:   1          Missing arguments, API communication errors, or broken/expired certificate
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

# Define target runtime directory and output path for the decoded CA certificate
runtime_dest="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
cert_target="${runtime_dest}/DBaaS_CERT"

# Ensure the destination runtime directory exists
if [ ! -d "${runtime_dest}" ]
then
        /bin/mkdir -p "${runtime_dest}"
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/databases/mysql/instances/${database_id}/ssl"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Fetch the Base64-encoded CA certificate via stdin-piped token and decode to a staging file
set +e
/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "${endpoint}" | /usr/bin/jq -r '.ca_certificate' | /bin/base64 --decode > "${cert_target}.tmp" 2>/dev/null
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ ! -s "${cert_target}.tmp" ]
then
        status "Failed to extract SSL parameters or interface with cloud platform API."
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

