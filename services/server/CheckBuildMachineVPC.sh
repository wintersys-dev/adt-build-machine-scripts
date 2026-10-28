#!/bin/sh
###################################################################################
# @file        CheckBuildMachineVPC.sh
# @brief       Verifies whether a provisioning build machine is properly routed into a VPC network block.
# @author      Peter Winter
# @date        15/02/2021
# @version     1.0
#
# @details     This script performs a baseline environmental check on a virtual machine.
#              It queries the active cloud host infrastructure layer to map the public 
#              IPv4 address to an internal label, then attempts to look up the machine's 
#              private networking interfaces. If no internal private IP addresses are 
#              returned, the machine is flagged as detached from its required VPC context.
#
# @param       $1  [Required] The targeted cloud hosting infrastructure platform slug.
# @param       $2  [Required] The public IPv4 address of the target deployment instance.
#
# @env         BUILD_HOME  Path to the framework core root layout directory.
#
# @exit        0  Success: The connectivity layout check sequence completed without errors.
# @exit        1  Failure: Missing positional parameters, unreadable environment configurations,
#                 or network mapping lookup execution failure.
#
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
###################################################################################
###################################################################################
#set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

cloudhost="${1}"
server_ip="${2}"

if ( [ "${cloudhost}" = "digitalocean" ] )
then
	server_name="`${BUILD_HOME}/services/server/GetServerName.sh ${server_ip}`"
	${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name} 
fi

if ( [ "${cloudhost}" = "exoscale" ] )
then
	server_name="`${BUILD_HOME}/services/server/GetServerName.sh ${server_ip}`"
	${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name} 
fi

if ( [ "${cloudhost}" = "linode" ] )
then
	server_name="`${BUILD_HOME}/services/server/GetServerName.sh ${server_ip}`"
	${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name} 
fi

if ( [ "${cloudhost}" = "vultr" ] )
then
	server_name="`${BUILD_HOME}/services/server/GetServerName.sh ${server_ip}`"
	if ( [ "${server_name}" = "" ] )
	then
		server_name="NOT_SET"
	fi
	${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh ${server_name}
fi
