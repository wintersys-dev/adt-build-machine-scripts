#!/bin/sh
#: Name:        get_file_contents.sh
#: Purpose:     Retrieves the raw contents of a single file from a GitLab project via REST API v4 (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       get_file_contents.sh <repository_name> <repository_ownername> <file_path> [branch_or_ref]
#:              get_file_contents.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the GitLab project to inspect.
#:   $2         [Required] The GitLab username or group path (repository owner).
#:   $3         [Required] The path to the file within the repository (e.g., dbp.dat or src/main.sh).
#:   $4         [Optional] Branch, tag, or commit SHA (defaults to project default_branch if omitted).
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - External binaries: cat, curl, cut, echo, grep, jq, mktemp, printf, rm, sed
#:
#: Exit Codes:
#:   0          Raw file contents printed to stdout
#:   1          Missing arguments, layout faults, connection error, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN)
#:   403        Forbidden (token lacks permissions to inspect target project)
#:   404        Not Found (project, branch/ref, or file path does not exist)
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to stderr so stdout remains clean for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Repository name, repository ownername, and file path arguments are required."
        status "Usage: $0 <repository_name> <repository_ownername> <file_path> [branch_or_ref]"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2}"
raw_file_path="$(/bin/echo "${3}" | /usr/bin/sed 's|^/||')"
git_ref="${4}"

tmp_response="$(/bin/mktemp /tmp/gl_file.XXXXXX.raw)"

cleanup() {
        /bin/rm -f "${tmp_response}"
}
trap cleanup EXIT INT TERM

encoded_project="$(/bin/echo "${repository_ownername}/${repository_name}" | /usr/bin/sed 's/\//%2F/g')"
encoded_file="$(/bin/echo "${raw_file_path}" | /usr/bin/sed 's/\//%2F/g; s/ /%20/g')"
api_base="https://gitlab.com/api/v4"
project_endpoint="${api_base}/projects/${encoded_project}"

use_auth=0
REPOSITORY_TOKEN=""

load_token() {
        if [ -z "${REPOSITORY_TOKEN}" ]
        then
                set +e
                REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
                set -e
        fi

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
        then
                use_auth=1
        fi
}

# 1. Resolve project default_branch if no branch/ref was explicitly provided
if [ -z "${git_ref}" ]
then
        set +e
        PROJECT_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${project_endpoint}")
        set -e

        if [ "${PROJECT_HTTP_CODE}" != "200" ]
        then
                load_token
                if [ "${use_auth}" -eq 1 ]
                then
                        : > "${tmp_response}"
                        set +e
                        PROJECT_HTTP_CODE=$(/usr/bin/printf 'PRIVATE-TOKEN: %s\n' "${REPOSITORY_TOKEN}" | \
                                /usr/bin/curl -s --connect-timeout 15 -H @- \
                                -o "${tmp_response}" \
                                -w "%{http_code}" \
                                "${project_endpoint}")
                        set -e
                fi
        fi

        if [ "${PROJECT_HTTP_CODE}" = "200" ]
        then
                git_ref="$(/usr/bin/jq -r '.default_branch // empty' "${tmp_response}" 2>/dev/null)"
        fi

        if [ -z "${git_ref}" ]
        then
                git_ref="HEAD"
        fi
fi

file_endpoint="${project_endpoint}/repository/files/${encoded_file}/raw?ref=${git_ref}"

# 2. Fetch raw file contents (public first unless auth was already initialized)
: > "${tmp_response}"
set +e
if [ "${use_auth}" -eq 1 ]
then
        FILE_HTTP_CODE=$(/usr/bin/printf 'PRIVATE-TOKEN: %s\n' "${REPOSITORY_TOKEN}" | \
                /usr/bin/curl -s --connect-timeout 15 -H @- \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${file_endpoint}")
else
        FILE_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${file_endpoint}")
fi
set -e

# 3. If unauthenticated file fetch failed, retry with PRIVATE-TOKEN
if [ "${FILE_HTTP_CODE}" != "200" ] && [ "${use_auth}" -eq 0 ]
then
        load_token
        if [ "${use_auth}" -eq 1 ]
        then
                : > "${tmp_response}"
                set +e
                FILE_HTTP_CODE=$(/usr/bin/printf 'PRIVATE-TOKEN: %s\n' "${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -s --connect-timeout 15 -H @- \
                        -o "${tmp_response}" \
                        -w "%{http_code}" \
                        "${file_endpoint}")
                set -e
        fi
fi

unset REPOSITORY_TOKEN

case "${FILE_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching gitlab.com."
                exit 1
                ;;
        200)
                /bin/cat "${tmp_response}"
                exit 0
                ;;
        404)
                status "Error 404: File '${3}' not found in ${repository_ownername}/${repository_name} at ref '${git_ref}' (or project is private without a valid token)."
                exit 404
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATION_REPOSITORY_TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks permissions to inspect ${repository_ownername}/${repository_name}."
                exit 403
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 429
                ;;
        5*)
                status "Error ${FILE_HTTP_CODE}: GitLab Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                FILE_BODY="$(/bin/cat "${tmp_response}" 2>/dev/null)"
                status "Error ${FILE_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${FILE_BODY}"
                exit 1
                ;;
esac

exit 0
