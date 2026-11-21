#!/bin/sh
#: Name:        get_file_contents.sh
#: Purpose:     Retrieves the raw contents of a single file from a Bitbucket repository via REST API (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       get_file_contents.sh <repository_name> <repository_ownername> <file_path> [branch_or_ref]
#:              get_file_contents.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the Bitbucket repository.
#:   $2         [Required] The Bitbucket workspace or repository owner name.
#:   $3         [Required] The path to the file within the repository (e.g., dbp.dat or src/main.sh).
#:   $4         [Optional] Branch, tag, or commit SHA (defaults to repository mainbranch if omitted).
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - External binaries: base64, cat, chmod, curl, cut, echo, grep, jq, mktemp, printf, rm, sed, tr
#:
#: Exit Codes:
#:   0          Raw file contents printed to stdout
#:   1          Missing arguments, layout faults, connection error, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN or email)
#:   403        Forbidden (token lacks permissions to inspect target repository)
#:   404        Not Found (repository, branch/ref, or file path does not exist)
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Repository name, repository ownername, and file path arguments are required."
        status "Usage: $0 <repository_name> <repository_ownername> <file_path> [branch_or_ref]"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2}"
clean_path="$(/bin/echo "${3}" | /usr/bin/sed 's|^/||; s/ /%20/g')"
git_ref="${4}"

tmp_response="$(/bin/mktemp /tmp/bb_file.XXXXXX.raw)"
tmp_curl_cfg="$(/bin/mktemp /tmp/bb_curl_cfg.XXXXXX)"
/bin/chmod 600 "${tmp_response}" "${tmp_curl_cfg}"

cleanup() {
        /bin/rm -f "${tmp_response}" "${tmp_curl_cfg}"
}
trap cleanup EXIT INT TERM

api_base="https://bitbucket.org"
repo_endpoint="${api_base}/repositories/${repository_ownername}/${repository_name}"

use_auth=0

prepare_auth() {
        if [ "${use_auth}" -eq 1 ]
        then
                return 0
        fi

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
        fi

        unset REPOSITORY_TOKEN ATLASSIAN_EMAIL
}

# 1. If no branch/ref was supplied, resolve the repository's default mainbranch first
if [ -z "${git_ref}" ]
then
        set +e
        REPO_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${repo_endpoint}")
        set -e

        if [ "${REPO_HTTP_CODE}" != "200" ]
        then
                prepare_auth
                if [ "${use_auth}" -eq 1 ]
                then
                        : > "${tmp_response}"
                        set +e
                        REPO_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
                                --config "${tmp_curl_cfg}" \
                                -o "${tmp_response}" \
                                -w "%{http_code}" \
                                "${repo_endpoint}")
                        set -e
                fi
        fi

        if [ "${REPO_HTTP_CODE}" = "200" ]
        then
                git_ref="$(/usr/bin/jq -r '.mainbranch.name // empty' "${tmp_response}" 2>/dev/null)"
        fi

        # Fallback to HEAD if mainbranch is unset or repo lookup returned a non-200 status
        if [ -z "${git_ref}" ]
        then
                git_ref="HEAD"
        fi
fi

file_endpoint="${repo_endpoint}/src/${git_ref}/${clean_path}"

# 2. Fetch the raw file contents (public first unless auth was already initialized)
: > "${tmp_response}"
set +e
if [ "${use_auth}" -eq 1 ]
then
        FILE_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
                --config "${tmp_curl_cfg}" \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${file_endpoint}")
else
        FILE_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
                -o "${tmp_response}" \
                -w "%{http_code}" \
                "${file_endpoint}")
fi
set -e

# 3. If unauthenticated file fetch failed, retry with credentials
if [ "${FILE_HTTP_CODE}" != "200" ] && [ "${use_auth}" -eq 0 ]
then
        prepare_auth
        if [ "${use_auth}" -eq 1 ]
        then
                : > "${tmp_response}"
                set +e
                FILE_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
                        --config "${tmp_curl_cfg}" \
                        -o "${tmp_response}" \
                        -w "%{http_code}" \
                        "${file_endpoint}")
                set -e
        fi
fi

case "${FILE_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching api.bitbucket.org."
                exit 1
                ;;
        200)
                /bin/cat "${tmp_response}"
                exit 0
                ;;
        404)
                status "Error 404: File '${3}' not found in ${repository_ownername}/${repository_name} at ref '${git_ref}' (or repository is private without a valid token)."
                exit 404
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
                status "Error ${FILE_HTTP_CODE}: Bitbucket Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                FILE_BODY="$(/bin/cat "${tmp_response}" 2>/dev/null)"
                status "Error ${FILE_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${FILE_BODY}"
                exit 1
                ;;
esac
