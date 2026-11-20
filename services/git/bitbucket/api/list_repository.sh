#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a Bitbucket repository state ("full", "empty", or "none") via REST API (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        20/11/2026
#: Version:     1.1
#:
#: Usage:       list_repository.sh <repository_ownername> <repository_name>
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The Bitbucket workspace or repository owner name.
#:   $2         [Required] The name/slug of the repository to inspect.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, jq, printf, sed
#:
#: Exit Codes:
#:   0          Repository state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, missing credentials, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN or email)
#:   403        Forbidden (token lacks permissions to inspect target repository)
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Repository owner name and repository name arguments are required."
        status "Usage: $0 <repository_ownername> <repository_name>"
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"

api_base="https://api.bitbucket.org/2.0"
repo_endpoint="${api_base}/repositories/${repository_ownername}/${repository_name}"
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

use_auth=0

# Step 1a: Attempt unauthenticated repository check first
set +e
REPO_RESPONSE=$(/usr/bin/curl -s --connect-timeout 15 \
        "${repo_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
set -e

REPO_HTTP_CODE=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Step 1b: If public access fails (e.g., 401/403/404 on private repo), retry with credentials
if [ "${REPO_HTTP_CODE}" != "200" ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        ATLASSIAN_EMAIL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_EMAIL' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ] && \
           [ -n "${ATLASSIAN_EMAIL}" ] && [ "${ATLASSIAN_EMAIL}" != "none" ]
        then
                use_auth=1
                set +e
                REPO_RESPONSE=$(/usr/bin/printf 'machine api.bitbucket.org login %s password %s\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -s --connect-timeout 15 --netrc-file /dev/stdin \
                        "${repo_endpoint}" \
                        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
                set -e
                REPO_HTTP_CODE=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
        fi
fi

REPO_BODY=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${REPO_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching api.bitbucket.org."
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 1
                ;;
        200)
                ;;
        404)
                /bin/echo "none"
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 0
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATION_REPOSITORY_TOKEN or APPLICATION_REPOSITORY_EMAIL is invalid or has expired."
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks permissions to inspect ${repository_ownername}/${repository_name}."
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 403
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 429
                ;;
        5*)
                status "Error ${REPO_HTTP_CODE}: Bitbucket Gateway or Remote Server Exception."
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 500
                ;;
        *)
                status "Error ${REPO_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${REPO_BODY}"
                unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
                exit 1
                ;;
esac

# Step 2: Check whether the repository has any commits ("full" vs "empty")
set +e
if [ "${use_auth}" -eq 1 ]
then
        COMMITS_RESPONSE=$(/usr/bin/printf 'machine api.bitbucket.org login %s password %s\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
                /usr/bin/curl -s --connect-timeout 15 --netrc-file /dev/stdin \
                "${commits_endpoint}" \
                -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
else
        COMMITS_RESPONSE=$(/usr/bin/curl -s --connect-timeout 15 \
                "${commits_endpoint}" \
                -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
fi
set -e

unset REPOSITORY_TOKEN ATLASSIAN_EMAIL

COMMITS_HTTP_CODE=$(/usr/bin/printf '%s\n' "${COMMITS_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
COMMITS_BODY=$(/usr/bin/printf '%s\n' "${COMMITS_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${COMMITS_HTTP_CODE}" in
        200)
                commit_count="$(/bin/echo "${COMMITS_BODY}" | /usr/bin/jq '.values | length' 2>/dev/null)"
                if [ -n "${commit_count}" ] && [ "${commit_count}" -gt 0 ]
                then
                        /bin/echo "full"
                else
                        /bin/echo "empty"
                fi
                exit 0
                ;;
        404|409)
                /bin/echo "empty"
                exit 0
                ;;
        *)
                status "Error ${COMMITS_HTTP_CODE}: Unexpected response querying repository commits."
                status "API Detail: ${COMMITS_BODY}"
                exit 1
                ;;
esac

