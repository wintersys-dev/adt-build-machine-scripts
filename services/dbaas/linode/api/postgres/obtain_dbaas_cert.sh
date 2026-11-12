#!/bin/sh
###################################################################################
# @file        obtain_dbaas_cert.sh
# @brief       Retrieves and validates the SSL CA Certificate for a Linode Managed Database.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script connects to the provider's SSL endpoint for a targeted 
#              database instance ID, extracts the Base64 encoded CA certificate, 
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
#              - external dependencies: cat, echo, curl, jq, base64, openssl, grep
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Prevents terminal process leak vulnerabilities by using clean temporary stream files.
#              - Masking API interactions securely via stream piping using the @- syntax.
#
# @exit        0  Success: Target database certificate successfully obtained, written, and verified.
# @exit        1  Failure: Missing arguments, API communication errors, or broken/expired cert parameters.
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
if [ -z "${1}" ]
# Target asset payload tracking metrics configuration
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

# Fetch payload parameters safely while using manual intercept hooks to catch runtime exceptions
set +e
/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/ssl" | /usr/bin/jq -r '.ca_certificate' | /bin/base64 --decode > "${cert_target}.tmp" 2>/dev/null
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ ! -s "${cert_target}.tmp" ]
then
        status "Failed to extract SSL parameters or interface with cloud platform API."
        /bin/rm -f "${cert_target}.tmp"
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
        exit 1
else 
        status "DBaaS certificate present and valid...OK to proceed"
fi

exit 0
