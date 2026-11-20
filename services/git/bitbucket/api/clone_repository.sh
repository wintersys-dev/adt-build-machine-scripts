#!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Downloads and extracts a Bitbucket repository branch archive via HTTP API (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        20/11/2026
#: Version:     1.2
#:
#: Usage:       clone_repository.sh [--branch] <branch> <repository_ownername> <repository_name> <destination_directory>
#:              clone_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target branch name (or "--branch" followed by branch name).
#:   $2         [Required] The Bitbucket workspace or repository owner name.
#:   $3         [Required] The name/slug of the repository to download.
#:   $4         [Required] Local destination directory for the extracted files.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, mkdir, mktemp, printf, rm, sed, tar
#:
#: Exit Codes:
#:   0          Repository archive downloaded and extracted cleanly
#:   1          Missing arguments, layout faults, extraction error, or unexpected HTTP code
#:   400        Bad Request (invalid branch or repository parameter syntax)
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN or email)
#:   403        Forbidden (token lacks read permissions for target repository)
#:   404        Not Found (repository or branch does not exist)
#:   429        Rate Limit Exceeded
#:   500        Bitbucket Gateway or Remote Server Exception (5xx)
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

if [ "${1}" = "--branch" ]
then
        shift
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: Branch, repository owner, repository name, and destination directory are required."
        status "Usage: $0 [--branch] <branch> <repository_ownername> <repository_name> <destination_directory>"
        exit 1
fi

branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

tmp_archive="$(/bin/mktemp /tmp/repo_archive.XXXXXX.tar.gz)"

cleanup() {
        /bin/rm -f "${tmp_archive}"
}
trap cleanup EXIT INT TERM

api_base="https://bitbucket.org"
repo_endpoint="${repository_ownername}/${repository_name}/get/${branch}.tar.gz"

# 1. Attempt unauthenticated download first
set +e
HTTP_CODE=$(/usr/bin/curl -s -L --connect-timeout 15 \
        -o "${tmp_archive}" \
        -w "%{http_code}" \
        "${api_base}/${repo_endpoint}")
set -e

# 2. If public access fails, retry with Atlassian email + API token
if [ "${HTTP_CODE}" != "200" ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        ATLASSIAN_EMAIL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_EMAIL' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ] && \
           [ -n "${ATLASSIAN_EMAIL}" ] && [ "${ATLASSIAN_EMAIL}" != "none" ]
        then
                /bin/rm -f "${tmp_archive}"
                set +e
                HTTP_CODE=$(/usr/bin/printf 'user = "%s:%s"\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -s -L --connect-timeout 15 -K - \
                        -o "${tmp_archive}" \
                        -w "%{http_code}" \
                        "${api_base}/${repo_endpoint}")
                set -e
        fi

        unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
fi

case "${HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching bitbucket.org."
                exit 1
                ;;
        200)
                /bin/mkdir -p "${destination_directory}"
                set +e
                /bin/tar -xzf "${tmp_archive}" -C "${destination_directory}" --strip-components=1 >&2
                tar_status="$?"
                set -e

                if [ "${tar_status}" -ne 0 ]
                then
                        status "Error: Failed to extract repository archive into ${destination_directory}."
                        exit 1
                fi

                /bin/echo "${destination_directory}"
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Check branch or repository parameter syntax."
                exit 400
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATION_REPOSITORY_TOKEN or APPLICATION_REPOSITORY_EMAIL is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks read permissions for ${repository_ownername}/${repository_name}."
                exit 403
                ;;
        404)
                status "Error 404: Not Found. Repository ${repository_ownername}/${repository_name} or branch '${branch}' does not exist."
                exit 404
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 429
                ;;
        5*)
                status "Error ${HTTP_CODE}: Bitbucket Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                status "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                exit 1
                ;;
esac


