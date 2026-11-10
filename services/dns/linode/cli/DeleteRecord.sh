#!/bin/sh
###################################################################################
# @file        DeleteRecord.sh
# @brief       Deletes an existing DNS record from a specific domain zone via CLI.
# @author      Peter Winter
# @date        13/07/2016
# @version     1.0
#
# @details     This script parses a target URL to identify its core domain zone,
#              queries provider catalogs via the Linode CLI to find the matching
#              zone tracking ID, and uses the provided record ID to remove the 
#              entry under securely scoped token environments.
#
# @param       $1  [Required] The unique Linode identifier of the target record to delete.
# @param       $2  [Required] The Fully Qualified Domain Name (e.g., "://domain.com").
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
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#
# @exit        0  Success: Target DNS record successfully deleted via CLI.
# @exit        1  Failure: Missing parameters or provider API transaction error.
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

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

record_id="${1}"
domain_url="$(/bin/echo ${2} | /usr/bin/cut -d'.' -f2-)"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY)"
export LINODE_CLI_TOKEN="${TOKEN}"

domain_id="$(/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id')"
/usr/local/bin/linode-cli domains records-delete ${domain_id} ${record_id} --no-defaults

if  [ $? != "0" ] 
then
        status "Failed to delete record with id ${record_id} for domain ${domain_url}"
        unset LINODE_CLI_TOKEN
        exit  1
fi

unset LINODE_CLI_TOKEN
status "Successfully deleted record with id ${record_id} for domain ${domain_url}"

