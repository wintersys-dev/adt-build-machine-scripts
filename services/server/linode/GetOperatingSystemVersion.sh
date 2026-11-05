#!/bin/sh
###################################################################################
# @file        GetOperatingSystemVersion.sh
# @brief       Translates raw OS distributions into provider-specific image slugs.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script takes a target OS distribution type and its associated 
#              version version string, validates them against platform rules, and 
#              outputs the matching formatted Linode API compatibility identifier slug.
#
# @param       $1  [Required] The OS distribution identifier (e.g., "ubuntu", "debian").
# @param       $2  [Required] The targeted OS major/minor version number string.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - external dependencies: cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin) to eliminate executable hijack vectors.
#              - Eliminates redundant subshell fork operations inside conditional tracks.
#              - Wraps structural parameter variables securely in strict text boundaries.
#
# @exit        0  Success: Target image slug was successfully resolved and printed.
# @exit        1  Failure: Missing positional arguments or unsupported OS type match.
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: buildos and buildos_version arguments are required."
        status "Usage: $0 <buildos> <buildos_version>"
        exit 1
fi

buildos="${1}"
buildos_version="${2}"

if [ "${buildos}" = "ubuntu" ]
then
        /bin/echo "linode/ubuntu${buildos_version}"
elif [ "${buildos}" = "debian" ]
then
        /bin/echo "linode/debian${buildos_version}"
else
        status "Error: Unsupported distribution identifier '${buildos}'." >&2
        exit 1
fi

exit 0

