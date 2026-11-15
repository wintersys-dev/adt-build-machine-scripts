#!/bin/sh
#: Name:        GetOperatingSystemVersion.sh
#: Purpose:     Translates raw OS distributions into Linode-specific image slugs.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetOperatingSystemVersion.sh <buildos> <buildos_version>
#:              GetOperatingSystemVersion.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The OS distribution identifier (e.g., "ubuntu", "debian").
#:   $2         [Required] The targeted OS major/minor version number string.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Target image slug was successfully resolved and printed
#:   1          Missing positional arguments, layout faults, or unsupported OS type
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

# Validate that both OS distribution and version arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: buildos and buildos_version arguments are required."
        status "Usage: $0 <buildos> <buildos_version>"
        exit 1
fi

buildos="${1}"
buildos_version="${2}"

# Map supported distribution identifiers to their corresponding Linode image slugs
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


