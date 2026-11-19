#!/bin/sh
#: Name:        ListRepository.sh
#: Purpose:     Orchestrates remote repository status checks across configured Git providers.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       ListRepository.sh <repository_provider> <repository_ownername> <repository_name>
#:              ListRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The Git provider name (e.g. bitbucket, github, gitlab).
#:   $2         [Required] The workspace or repository owner name.
#:   $3         [Required] The name/slug of the repository to inspect.
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/services/git/${repository_provider}/ListRepository.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Repository check delegated and completed cleanly by provider sub-driver
#:   1          Missing arguments, layout faults, missing/non-executable sub-driver, or check failure
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
        status "Application root configuration file missing at /home/buildhome.dat" 
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: 3 arguments are required" 
        status "Usage: $0 <repository_provider> <repository_ownername> <repository_name> "
        exit 1
fi

repository_provider="${1:-${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_PROVIDER')}"
repository_ownername="${2}"
repository_name="${3}"

# Verify provider sub-driver script exists and is executable before delegating
provider_script="${BUILD_HOME}/services/git/${repository_provider}/ListRepository.sh"

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

# Delegate remote repository check to the provider-specific sub-driver
set +e
"${provider_script}" "${repository_ownername}" "${repository_name}" 
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: ${provider_script} returned error code ${exit_code}."
        exit 1
fi

exit 0


