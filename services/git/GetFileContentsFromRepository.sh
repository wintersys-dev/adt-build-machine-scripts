#!/bin/sh
#: Name:        GetFile.sh
#: Purpose:     Orchestrates single-file retrieval across configured Git providers.
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       GetFile.sh <repository_name> <file_path> [repository_provider] [repository_ownername] [branch_or_ref]
#:              GetFile.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to inspect.
#:   $2         [Required] The path to the file within the repository (e.g., dbp.dat or src/main.sh).
#:   $3         [Optional] The Git provider name (e.g. bitbucket, github, gitlab).
#:   $4         [Optional] The workspace or repository owner name.
#:   $5         [Optional] Branch, tag, or commit SHA (defaults to repository default branch if omitted).
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - ${BUILD_HOME}/services/git/${repository_provider}/GetFile.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Raw file contents retrieved and printed to stdout by provider sub-driver
#:   1          Missing arguments, layout faults, missing/non-executable sub-driver, or retrieval failure
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

# Route status log entries to the centralized logging utility on stderr
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: <repository_name> and <file_path> arguments are required."
        status "Usage: $0 <repository_name> <file_path> [repository_provider] [repository_ownername] [branch_or_ref]"
        exit 1
fi

repository_name="${1}"
file_path="${2}"
repository_provider="${3:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" 'APPLICATION_REPOSITORY_PROVIDER')}"
repository_ownername="${4:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" 'APPLICATION_REPOSITORY_OWNER')}"
git_ref="${5}"

# Ensure optional parameters resolved cleanly either via CLI or environment fallback
if [ -z "${repository_provider}" ] || [ -z "${repository_ownername}" ]
then
        status "Error: Could not resolve repository_provider or repository_ownername from arguments or toolkit configuration"
        exit 1
fi

# Verify provider sub-driver script exists and is executable before delegating
provider_script="${BUILD_HOME}/services/git/${repository_provider}/GetFile.sh"

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

# Delegate single-file retrieval to the provider-specific sub-driver
set +e
if [ -n "${git_ref}" ]
then
        "${provider_script}" "${repository_name}" "${repository_ownername}" "${file_path}" "${git_ref}"
else
        "${provider_script}" "${repository_name}" "${repository_ownername}" "${file_path}"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: ${provider_script} returned error code ${exit_code}."
        exit 1
fi

exit 0
