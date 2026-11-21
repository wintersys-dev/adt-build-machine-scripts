#!/bin/sh
#: Name:        CloneRepository.sh
#: Purpose:     Orchestrates repository cloning across configured Git providers.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       CloneRepository.sh  <repository_name> <repository_branch> <destination_directory> [repository_provider] [repository_ownername]
#:              CloneRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to clone.
#:   $2         [Required] The target branch name to clone.
#:   $3         [Required] The local destination directory path.
#:   $4         [Optional] The Git provider name (e.g. bitbucket, github, gitlab).
#:   $5         [Optional] The workspace or repository owner name.

#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/services/git/${repository_provider}/CloneRepository.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Repository cloned cleanly by provider sub-driver
#:   1          Missing arguments, layout faults, missing/non-executable sub-driver, or clone failure
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

# Resolve the toolkit root directory from the server tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        status "Error: 3 arguments are required with 2 optional argument." 
        status "Usage: $0  <repository_name> <repository_branch> <destination_directory> [repository_provider] [repository_ownername]" 
        exit 1
fi

repository_name="${1}"
repository_branch="${2}"
destination_directory="${3}"
repository_provider="${4:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" 'APPLICATION_REPOSITORY_PROVIDER')}"
repository_ownername="${5:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" 'APPLICATION_REPOSITORY_PROVIDER')}"

# Verify provider sub-driver script exists and is executable before delegating
provider_script="${BUILD_HOME}/services/git/${repository_provider}/CloneRepository.sh"

if [ ! -f "${provider_script}" ]
then
        status "Error: Git provider script not found at ${provider_script}" 
        exit 1
fi

if [ ! -x "${provider_script}" ]
then
        status "Error: Git provider script at ${provider_script} is not executable." 
        exit 1
fi

# Delegate clone operation to the provider-specific sub-driver
set +e
"${provider_script}" "${repository_name}" "${repository_branch}" "${destination_directory}" "${repository_ownername}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: ${provider_script} exited with error code ${exit_code}." 
        exit 1
fi

exit 0


