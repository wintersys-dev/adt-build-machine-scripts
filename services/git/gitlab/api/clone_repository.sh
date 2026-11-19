#!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Downloads and extracts a GitLab project branch archive via REST API v4.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       clone_repository.sh <branch> <repository_ownername> <repository_name> <destination_directory>
#:              clone_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target branch name or "--branch <name>" flag.
#:   $2         [Required] The GitLab username or group path (repository owner).
#:   $3         [Required] The name/slug of the GitLab project to download.
#:   $4         [Required] Local destination directory for the extracted files.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, mkdir, mktemp, rm, sed, tar
#:
#: Exit Codes:
#:   0          Project archive downloaded and extracted cleanly
#:   1          Missing arguments, layout faults, extraction error, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATIONREPOSITORYTOKEN)
#:   403        Forbidden (token lacks read permissions for target project)
#:   404        Not Found (project or branch does not exist)
#:   429        Rate Limit Exceeded
#:   500        GitLab Gateway or Remote Server Exception (5xx)
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

#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" 
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: Branch, repository owner, repository name, and destination directory are required." 
        status "Usage: $0 <branch> <repository_ownername> <repository_name> <destination_directory>"
        exit 1
fi

branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_PROVIDER')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN)." 
        exit 1
fi

tmp_archive="$(/bin/mktemp /tmp/repo_archive.XXXXXX.tar.gz)"

cleanup() {
        /bin/rm -f "${tmp_archive}"
}
trap cleanup EXIT INT TERM

# URL-encode slashes in owner/project path for GitLab v4 API
encoded_project="$(/bin/echo "${repository_ownername}/${repository_name}" | /usr/bin/sed 's/\//%2F/g')"
api_base="https://gitlab.com/api/v4"
endpoint_url="${api_base}/projects/${encoded_project}/repository/archive.tar.gz?sha=${branch}"

set +e
HTTP_CODE=$(/bin/echo "PRIVATE-TOKEN: ${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s -L -H @- \
        -o "${tmp_archive}" \
        -w "%{http_code}" \
        "${endpoint_url}")
set -e

case "${HTTP_CODE}" in
        200)
                /bin/mkdir -p "${destination_directory}"
                set +e
                /bin/tar -xzf "${tmp_archive}" -C "${destination_directory}" --strip-components=1 >&2
                tar_status="$?"
                set -e

                if [ "${tar_status}" -ne 0 ]
                then
                        /bin/echo "Error: Failed to extract project archive into ${destination_directory}." >&2
                        exit 1
                fi

                /bin/echo "${destination_directory}"
                exit 0
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATIONREPOSITORYTOKEN is invalid or has expired." 
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks read permissions for ${repository_ownername}/${repository_name}." 
                exit 403
                ;;
        404)
                status "Error 404: Not Found. Project ${repository_ownername}/${repository_name} or branch '${branch}' does not exist." 
                exit 404
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency." 
                exit 429
                ;;
        5*)
                status "Error ${HTTP_CODE}: GitLab Gateway or Remote Server Exception." 
                exit 500
                ;;
        *)
                status "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." 
                exit 1
                ;;
esac

exit 0
