#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a Bitbucket Git repository state ("full", "empty", or "none") via Git CLI (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.2
#:
#: Usage:       list_repository.sh <repository_name> [repository_ownername]
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to inspect.
#:   $2         [Optional] The Bitbucket workspace or repository owner name.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: base64, cat, cut, echo, git, grep, printf, tr
#:
#: Exit Codes:
#:   0          Repository state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, layout faults, authentication error, or network failure
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

repo_url="https://bitbucket.org/${repository_ownername}/${repository_name}.git"

export GIT_TERMINAL_PROMPT=0

# 1. Attempt unauthenticated ls-remote first
set +e
ls_output="$(/usr/bin/git ls-remote "${repo_url}" 2>&1)"
git_status="$?"
set -e

# 2. If unauthenticated ls-remote fails, retry with Bitbucket Basic Auth header
if [ "${git_status}" -ne 0 ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
        then
                encoded_auth="$(/usr/bin/printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | /usr/bin/base64 | /usr/bin/tr -d '\n')"
                unset REPOSITORY_TOKEN

                if [ -z "${encoded_auth}" ]
                then
                        unset GIT_TERMINAL_PROMPT
                        status "Error: Failed to encode Bitbucket authentication header."
                        exit 1
                fi

                export GIT_CONFIG_COUNT=1
                export GIT_CONFIG_KEY_0="http.extraheader"
                export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

                set +e
                ls_output="$(/usr/bin/git ls-remote "${repo_url}" 2>&1)"
                git_status="$?"
                set -e

                unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 encoded_auth
        else
                unset REPOSITORY_TOKEN
        fi
fi

unset GIT_TERMINAL_PROMPT

if [ "${git_status}" -ne 0 ]
then
        if /bin/echo "${ls_output}" | /usr/bin/grep -qiE 'not found|does not exist'
        then
                /bin/echo "none"
                exit 0
        else
                status "Error: git ls-remote failed for ${repository_ownername}/${repository_name}: ${ls_output}"
                exit 1
        fi
fi

if /bin/echo "${ls_output}" | /usr/bin/grep -q 'HEAD'
then
        /bin/echo "full"
else
        /bin/echo "empty"
fi

exit 0

