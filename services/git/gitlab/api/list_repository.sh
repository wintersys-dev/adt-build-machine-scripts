#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a GitLab project state ("full", "empty", or "none") via REST API v4 (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.2
#:
#: Usage:       list_repository.sh <repository_name> [repository_ownername]
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the GitLab project to inspect.
#:   $2         [Optional] The GitLab username or group path (repository owner).
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, jq, mktemp, printf, rm, sed
#:
#: Exit Codes:
#:   0          Project state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, connection error, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN)
#:   403        Forbidden (token lacks permissions to inspect target project)
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

if [ -z "${1}" ]
then
        status "Error: Repository name argument is required."
        status "Usage: $0 <repository_name> [repository_ownername]"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" 'APPLICATION_REPOSITORY_OWNER')}"

if [ -z "${repository_ownername}" ]
then
        status "Error: Could not resolve repository_ownername from arguments or toolkit configuration."
        exit 1
fi

tmp_response="$(/bin/mktemp /tmp/repo_list.XXXXXX.json)"

cleanup() {
        /bin/rm -f "${tmp_response}"
}
trap cleanup EXIT INT TERM

encoded_project="$(/bin/echo "${repository_ownername}/${repository_name}" | /usr/bin/sed 's/\//%2F/g')"
api_base="https://gitlab.com/api/v4"
project_endpoint="${api_base}/projects/${encoded_project}"

# 1. Attempt unauthenticated lookup first (works for public projects without touching credentials)
set +e
PROJECT_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
        -o "${tmp_response}" \
        -w "%{http_code}" \
        "${project_endpoint}")
set -e

# 2. If public access fails (e.g., 404/403/401 on a private project), retry with PRIVATE-TOKEN
if [ "${PROJECT_HTTP_CODE}" != "200" ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
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

        unset REPOSITORY_TOKEN
fi

case "${PROJECT_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching gitlab.com."
                exit 1
                ;;
        200)
                repo_state="$(/usr/bin/jq -r '
                if .empty_repo == false then "full"
                elif .empty_repo == true then "empty"
                elif .default_branch != null then "full"
                else "empty"
                end
                ' "${tmp_response}" 2>/dev/null)"
                /bin/echo "${repo_state:-empty}"
                exit 0
                ;;
        404)
                /bin/echo "none"
                exit 0
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
                status "Error ${PROJECT_HTTP_CODE}: GitLab Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                PROJECT_BODY="$(/bin/cat "${tmp_response}" 2>/dev/null)"
                status "Error ${PROJECT_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${PROJECT_BODY}"
                exit 1
                ;;
esac

exit 0

