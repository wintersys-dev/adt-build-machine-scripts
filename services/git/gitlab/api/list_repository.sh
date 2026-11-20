#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a GitLab project state ("full", "empty", or "none") via REST API v4.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       list_repository.sh <repository_ownername> <repository_name>
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The GitLab username or group path (repository owner).
#:   $2         [Required] The name/slug of the GitLab project to inspect.
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: cat, curl, cut, echo, grep, jq, sed
#:
#: Exit Codes:
#:   0          Project state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, missing credentials, or unexpected HTTP code
#:   401        Unauthorized (invalid or expired APPLICATIONREPOSITORYTOKEN)
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
REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN')"
set -e


if [ -z "${REPOSITORY_TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (APPLICATION_REPOSITORY_TOKEN)." 
        exit 1
fi

encoded_project="$(/bin/echo "${repository_ownername}/${repository_name}" | /usr/bin/sed 's/\//%2F/g')"
api_base="https://gitlab.com/api/v4"
project_endpoint="${api_base}/projects/${encoded_project}"


CLEAN_TOKEN="$(printf '%s' "${REPOSITORY_TOKEN}" | /usr/bin/tr -d '\r\n')"

set +e
PROJECT_RESPONSE=$(/usr/bin/curl -s \
        -H "PRIVATE-TOKEN: ${CLEAN_TOKEN}" \
        "${project_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}")
set -e


PROJECT_HTTP_CODE=$(/bin/echo "${PROJECT_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
PROJECT_BODY=$(/bin/echo "${PROJECT_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${PROJECT_HTTP_CODE}" in
        200)
                is_empty="$(/bin/echo "${PROJECT_BODY}" | /usr/bin/jq -r 'if .empty_repo == null then "" else (.empty_repo | tostring) end' 2>/dev/null)"
                if [ "${is_empty}" = "false" ]
                then
                        /bin/echo "full"
                else
                        /bin/echo "empty"
                fi
                exit 0
                ;;
        404)
                /bin/echo "none"
                exit 0
                ;;
        401)
                status "Error 401: Unauthorized. Your APPLICATIONREPOSITORYTOKEN is invalid or has expired." 
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
                status "Error ${PROJECT_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." 
                status "API Detail: ${PROJECT_BODY}" 
                exit 1
                ;;
esac

exit 0
