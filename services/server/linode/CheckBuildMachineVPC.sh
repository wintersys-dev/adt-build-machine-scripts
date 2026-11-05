#!/bin/sh
###################################################################################
# @file        GetServerPrivateIPs.sh
# @brief       Resolves internal private network interfaces for an infrastructure instance.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script validates a target buildmachine identifier, safely 
#              decodes its corresponding infrastructure label hostname, and interfaces
#              with centralized lookup rules to dump all assigned private IP routing nodes.
#
# @param       $1  [Required] The management or public IP address of the target buildmachine.
#              
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetServerName.sh resolution script tracking host translation tables.
#              - GetServerPrivateIPAddresses.sh lookup mapping tool extracting active networks.
#              - external dependencies: cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin) to eliminate executable hijack vectors.
#              - Wraps structural platform executions cleanly inside localized environment contexts.
#
# @exit        0  Success: Target server configurations resolved safely without network errors.
# @exit        1  Failure: Missing positional arguments or runtime context tracking path failure.
##################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
####################################################################################
set -e

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

if [ -z "${1}" ] 
then
        status "Error: buildmachine IP argument is required."
        status "Usage: $0 <buildmachine_ip>"
        exit 1
fi

buildmachine_ip="${1}"

server_name="$("${BUILD_HOME}/services/server/GetServerName.sh" "${buildmachine_ip}")"

private_ips="$(${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh "${server_name}")"

if [ -z "${private_ips}" ]
then
        status "VPC for the build machine doesn't seem to be active or configured, please investigate you need to attach a valid VPC when provisioning the buld machine"
        exit 1
fi
        

exit 0
