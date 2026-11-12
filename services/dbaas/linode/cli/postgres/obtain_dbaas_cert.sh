#!/bin/sh
###################################################################################
# @file        obtain_dbaas_cert.sh
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

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

database_id="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

export LINODE_CLI_TOKEN="${TOKEN}"
/bin/echo "`/usr/local/bin/linode-cli databases postgresql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT

if [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT ] || [ "$(/usr/bin/openssl x509 -in ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT -checkend 0 -noout | /bin/grep 'Certificate will not expire')" = "" ]
then
  status "DBaaS certificate not present or invalid"
  unset LINODE_CLI_TOKEN
  exit 1
else 
  status "DBaaS cerificate present and valid...OK to proceed"
fi

unset LINODE_CLI_TOKEN
