#!/bin/sh
#: Name:        GetFileContentsFromRepository.sh
#: Purpose:     Retrieves the raw contents of a single file from a GitHub repository.
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       GetFileContentsFromRepository.sh <repository_name> <repository_ownername> <file_path> [branch_or_ref]
#:              GetFileContentsFromRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the GitHub repository.
#:   $2         [Required] The GitHub username or organization name (repository owner).
#:   $3         [Required] The path to the file within the repository (e.g., dbp.dat or src/main.sh).
#:   $4         [Optional] Branch, tag, or commit SHA (defaults to repository default branch if omitted).
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - ${BUILD_HOME}/services/git/github/${orchestration_tool}/get_file.sh
#:   - External binaries: awk, cat, cut, echo, grep, tr
#:
#: Exit Codes:
#:   0          Raw file contents printed to stdout
#:   1          Missing arguments, layout faults, configuration errors, or worker failure
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

set -e

if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Repository name, repository ownername, and file path arguments are required."
        status "Usage: $0 <repository_name> <repository_ownername> <file_path> [branch_or_ref]"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2}"
file_path="${3}"
git_ref="${4}"

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

worker_script="${BUILD_HOME}/services/git/github/${orchestration_tool}/get_file_contents.sh"

if [ ! -x "${worker_script}" ]
then
        status "Error: Provider file retrieval script not found or not executable at ${worker_script}"
        exit 1
fi

set +e
if [ -n "${git_ref}" ]
then
        "${worker_script}" "${repository_name}" "${repository_ownername}" "${file_path}" "${git_ref}"
else
        "${worker_script}" "${repository_name}" "${repository_ownername}" "${file_path}"
fi
worker_status="$?"
set -e

if [ "${worker_status}" -eq 0 ]
then
        exit 0
else
        status "File retrieval failed for '${file_path}' in ${repository_ownername}/${repository_name}. Check your API token, file path, or configuration."
        exit "${worker_status}"
fi
