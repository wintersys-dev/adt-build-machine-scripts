#!/bin/sh
#: Name:        CloneRepository.sh
#: Purpose:     Clones or downloads a remote Bitbucket Git repository branch to a local path.
#: Author:      Peter Winter
#: Date:        20/11/2026
#: Version:     1.1
#:
#: Usage:       CloneRepository.sh <repository_name> <repository_branch> <destination_directory> <repository_ownername> 
#:              CloneRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to clone.
#:   $2         [Required] The target branch name to clone.
#:   $3         [Required] The local destination directory path.
#:   $4         [Required] The Bitbucket workspace or repository owner name.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/git/bitbucket/${orchestration_tool}/clone_repository.sh
#:   - External binaries: awk, cat, cut, echo, grep, ls, tr
#:
#: Exit Codes:
#:   0          Repository cloned cleanly and destination directory populated
#:   1          Missing arguments, layout faults, configuration errors, or clone failure
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
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: Missing required arguments."
        status "Usage: $0 <repository_name> <repository_branch> <destination_directory>  <repository_ownername> "
        exit 1
fi

repository_name="${1}"
repository_branch="${2}"
destination_directory="${3}"
repository_ownername="${4}"

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

worker_script="${BUILD_HOME}/services/git/bitbucket/${orchestration_tool}/clone_repository.sh"

if [ ! -x "${worker_script}" ]
then
        status "Error: Provider clone script not found or not executable at ${worker_script}"
        exit 1
fi

set +e
output="$(${worker_script} "${repository_name}" "${repository_branch}" "${destination_directory}" "${repository_ownername}"  )"
clone_status="$?"
set -e

if [ "${clone_status}" -eq 0 ] && [ -d "${destination_directory}" ] && [ -n "$(/bin/ls -A "${destination_directory}")" ]
then
        /bin/echo "${output}"
else
        /bin/echo "failed"
        status "Git clone failed for ${repository_ownername}/${repository_name}. Check your API token, branch, or repository URL."
        exit 1
fi

exit 0

