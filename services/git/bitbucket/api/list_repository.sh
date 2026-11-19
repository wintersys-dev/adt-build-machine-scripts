#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a Bitbucket repository state ("full", "empty", or "none") via REST API.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       list_repository.sh <repository_ownername> <repository_name>
#:
#: Parameters:
#:   $1         [Required] The Bitbucket workspace or repository owner name.
#:   $2         [Required] The name/slug of the repository to inspect.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, jq, sed
#:
#: Exit Codes:
#:   0          Repository state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, missing credentials, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATIONREPOSITORYTOKEN or email)
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Repository owner name and repository name arguments are required." 
        status "Usage: $0 <repository_ownername> <repository_name>" 
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"

set +e
REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_PROVIDER')"
ATLASSIAN_EMAIL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_EMAIL')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        status "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN or APPLICATIONREPOSITORYEMAIL)."
        exit 1
fi

# Build the Bitbucket v2.0 REST API endpoints beforehand
api_base="https://api.bitbucket.org/2.0"
repo_endpoint="${api_base}/repositories/${repository_ownername}/${repository_name}"
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

# Step 1: Check whether the repository exists
set +e
REPO_RESPONSE=$(printf 'machine api.bitbucket.org login %s password %s\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s --netrc-file /dev/stdin \
        "${repo_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
set -e

REPO_HTTP_CODE=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
REPO_BODY=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')


case "${REPO_HTTP_CODE}" in
        200)
                # Repository exists; proceed to check for commits
                ;;
        404)
                /bin/echo "none"
                exit 0
                ;;
        401)
                status "Error 401: Unauthorized. Your REPOSITORY_TOKEN or ATLASSIAN_EMAIL is invalid or has expired." 
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
                status "Error ${REPO_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." 
                status "API Detail: ${REPO_BODY}" 
                exit 1
                ;;
esac

# Step 2: Check whether the repository has any commits ("full" vs "empty")
set +e
COMMITS_RESPONSE=$(printf 'machine api.bitbucket.org login %s password %s\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s --netrc-file /dev/stdin \
        "${commits_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
set -e

COMMITS_HTTP_CODE=$(printf '%s\n' "${COMMITS_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
COMMITS_BODY=$(printf '%s\n' "${COMMITS_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

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
                # Empty repositories with an unborn HEAD can return 404/409 on /commits
                /bin/echo "empty"
                exit 0
                ;;
        *)
                status "Error ${COMMITS_HTTP_CODE}: Unexpected response querying repository commits." 
                /bin/echo "API Detail: ${COMMITS_BODY}" >&2
                exit 1
                ;;
esac

exit 0
