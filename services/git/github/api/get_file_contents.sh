#!/bin/sh
#: Name:        get_file_contents.sh
#: Purpose:     Retrieves the raw contents of a single file from a GitHub repository via REST API (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       get_file_contents.sh <repository_name> <repository_ownername> <file_path> [branch_or_ref]
#:              get_file_contents.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the GitHub repository.
#:   $2         [Required] The GitHub username or organization (repository owner).
#:   $3         [Required] The path to the file within the repository (e.g., src/main.sh).
#:   $4         [Optional] Branch, tag, or commit SHA (defaults to repository default branch if omitted).
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - External binaries: cat, curl, cut, echo, grep, mktemp, printf, rm, sed
#:
#: Exit Codes:
#:   0          Raw file contents printed to stdout
#:   1          Missing arguments, layout faults, connection error, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATION_REPOSITORY_TOKEN)
#:   403        Forbidden (token lacks permissions or secondary rate limit hit)
#:   404        Not Found (repository, branch/ref, or file path does not exist)
#:   429        Rate Limit Exceeded
#:   500        GitHub Gateway or Remote Server Exception (5xx)
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
file_path="${3}"
git_ref="${4}"

tmp_response="$(/bin/mktemp /tmp/github_file.XXXXXX.raw)"

cleanup() {
        /bin/rm -f "${tmp_response}"
}
trap cleanup EXIT INT TERM

# Strip any leading slash from file_path and URL-encode spaces if present
clean_path="$(/bin/echo "${file_path}" | /usr/bin/sed 's|^/||; s/ /%20/g')"
api_base="https://api.github.com"
file_endpoint="${api_base}/repos/${repository_ownername}/${repository_name}/contents/${clean_path}"

if [ -n "${git_ref}" ]
then
        file_endpoint="${file_endpoint}?ref=${git_ref}"
fi

# 1. Attempt unauthenticated lookup first (works for public repositories without touching credentials)
set +e
FILE_HTTP_CODE=$(/usr/bin/curl -sL --connect-timeout 15 \
        -H "Accept: application/vnd.github.raw+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o "${tmp_response}" \
        -w "%{http_code}" \
        "${file_endpoint}")
set -e

# 2. If public access fails (e.g., 404/403/401 on a private repository), retry with Bearer token
if [ "${FILE_HTTP_CODE}" != "200" ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
        then
                : > "${tmp_response}"
                set +e
                FILE_HTTP_CODE=$(/usr/bin/printf 'Authorization: Bearer %s\n' "${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -sL --connect-timeout 15 \
                        -H "Accept: application/vnd.github.raw+json" \
                        -H @- \
                        -o "${tmp_response}" \
                        -w "%{http_code}" \
                        "${file_endpoint}")
                set -e
        fi

        unset REPOSITORY_TOKEN
fi

case "${FILE_HTTP_CODE}" in
        000)
                status "Error 000: Connection failed or timed out while reaching ://github.com."
                exit 1
                ;;
        200)
                /bin/cat "${tmp_response}"
                exit 0
                ;;
        404)
                status "Error 404: File '${file_path}' not found in ${repository_ownername}/${repository_name} (or repository is private without a valid token)."
                exit 404
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATION_REPOSITORY_TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks permissions for ${repository_ownername}/${repository_name} or rate limit exceeded."
                exit 403
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 429
                ;;
        5*)
                status "Error ${FILE_HTTP_CODE}: GitHub Gateway or Remote Server Exception."
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
