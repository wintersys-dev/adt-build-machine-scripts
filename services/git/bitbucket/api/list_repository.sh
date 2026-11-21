#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a Bitbucket repository state ("full", "empty", or "none") via REST API (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.4
#:
#: Usage:       list_repository.sh <repository_name> <repository_ownername>
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to inspect.
#:   $2         [Required] The Bitbucket workspace or repository owner name.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: base64, cat, chmod, curl, cut, echo, grep, jq, mktemp, printf, rm, tr
#:
#: Exit Codes:
#:   0          Repository state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, connection error, or unexpected HTTP code
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

if [ -z "${1}" ]
then
        status "Error: Repository name and repository ownername arguments are required."
        status "Usage: $0 <repository_name> <repository_ownername>"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2}"

tmp_response="$(/bin/mktemp /tmp/bb_repo_list.XXXXXX.json)"
tmp_curl_cfg="$(/bin/mktemp /tmp/bb_curl_cfg.XXXXXX)"
/bin/chmod 600 "${tmp_response}" "${tmp_curl_cfg}"

cleanup() {
        /bin/rm -f "${tmp_response}" "${tmp_curl_cfg}"
}
trap cleanup EXIT INT TERM

api_base="https://api.bitbucket.org/2.0"
repo_endpoint="${api_base}/repositories/${repository_ownername}/${repository_name}"
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

use_auth=0

# 1. Attempt unauthenticated lookup first (works for public repositories)
set +e
REPO_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
        -o "${tmp_response}" \
        -w "%{http_code}" \
        "${repo_endpoint}")
set -e

# 2. If public access fails, load credentials and build a secure 0600 curl config file
if [ "${REPO_HTTP_CODE}" != "200" ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN')"
        ATLASSIAN_EMAIL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_EMAIL')"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
        then
                if [ -n "${ATLASSIAN_EMAIL}" ] && [ "${ATLASSIAN_EMAIL}" != "none" ]
                then
                        encoded_auth="$(/usr/bin/printf '%s' "${ATLASSIAN_EMAIL}:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0 2>/dev/null || /usr/bin/printf '%s' "${ATLASSIAN_EMAIL}:${REPOSITORY_TOKEN}" | /usr/bin/base64 | /usr/bin/tr -d '\r\n')"
                        /usr/bin/printf 'header = "Authorization: Basic %s"\n' "${encoded_auth}" > "${tmp_curl_cfg}"
                        unset encoded_auth
                else
                        /usr/bin/printf 'header = "Authorization: Bearer %s"\n' "${REPOSITORY_TOKEN}" > "${tmp_curl_cfg}"
                fi

                use_auth=1
                : > "${tmp_response}"
                set +e
                REPO_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
                        --config "${tmp_curl_cfg}" \
                        -o "${tmp_response}" \
                        -w "%{http_code}" \
                        "${repo_endpoint}")
                set -e
        fi

        unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
fi

case "${REPO_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching api.bitbucket.org."
                exit 1
                ;;
        200)
                ;;
        404)
                /bin/echo "none"
                exit 0
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATION_REPOSITORY_TOKEN or APPLICATION_REPOSITORY_EMAIL is invalid or has expired."
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
                status "Error ${REPO_HTTP_CODE}: Bitbucket Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                REPO_BODY="$(/bin/cat "${tmp_response}" 2>/dev/null)"
                status "Error ${REPO_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${REPO_BODY}"
                exit 1
                ;;
esac

# 3. Check whether the repository has any commits ("full" vs "empty")
: > "${tmp_response}"
set +e
if [ "${use_auth}" -eq 1 ]
then
        COMMITS_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
                --config "${tmp_curl_cfg}" \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${commits_endpoint}")
else
        COMMITS_HTTP_CODE=$(/usr/bin/curl -s --connect-timeout 15 \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${commits_endpoint}")
fi
set -e

case "${COMMITS_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while querying repository commits."
                exit 1
                ;;
        200)
                commit_count="$(/usr/bin/jq '.values | length' "${tmp_response}" 2>/dev/null)"
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
                COMMITS_BODY="$(/bin/cat "${tmp_response}" 2>/dev/null)"
                status "Error ${COMMITS_HTTP_CODE}: Unexpected response querying repository commits."
                status "API Detail: ${COMMITS_BODY}"
                exit 1
                ;;
esac

