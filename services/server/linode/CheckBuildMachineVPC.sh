#!/bin/sh
#: Name:        GetServerPrivateIPs.sh
#: Purpose:     Resolves internal private network interfaces for an infrastructure instance.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPrivateIPs.sh <buildmachine_ip>
#:              GetServerPrivateIPs.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The management or public IP address of the target buildmachine.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetServerName.sh
#:   - GetServerPrivateIPAddresses.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Target server VPC private IP configurations resolved safely
#:   1          Missing arguments, layout faults, or unconfigured/inactive VPC
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

# Validate that the required buildmachine IP address argument was provided
if [ -z "${1}" ]
then
        status "Error: buildmachine IP argument is required."
        status "Usage: $0 <buildmachine_ip>"
        exit 1
fi

buildmachine_ip="${1}"

# Resolve the cloud provider server label/hostname from its public IP address
server_name="$("${BUILD_HOME}/services/server/GetServerName.sh" "${buildmachine_ip}")"

# Query all private VPC IP addresses attached to the resolved server label
private_ips="$("${BUILD_HOME}/services/server/GetServerPrivateIPAddresses.sh" "${server_name}")"

# Verify that at least one private VPC IP address is active on the build machine
if [ -z "${private_ips}" ]
then
        status "VPC for the build machine doesn't seem to be active or configured, please investigate you need to attach a valid VPC when provisioning the build machine"
        exit 1
fi

exit 0

