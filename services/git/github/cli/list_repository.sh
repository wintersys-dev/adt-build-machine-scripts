#!/bin/sh
#: Name:        list_repository.sh
#: Purpose:     Checks a GitHub repository state ("full", "empty", or "none") via Git CLI (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        20/11/2026
#: Version:     1.2
#:
#: Usage:       list_repository.sh <repository_ownername> <repository_name>
#:              list_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The GitHub organisation or account owner name.
#:   $2         [Required] The name/slug of the repository to inspect.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - External binaries: base64, cat, cut, echo, git, grep, printf
#:
#: Exit Codes:
#:   0          Repository state ("full", "empty", or "none") printed to stdout
#:   1          Missing arguments, framework layout faults, or authentication encoding failure
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

#set -x
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
git_base="https://github.com"
repo_url="${git_base}/${repository_ownername}/${repository_name}.git"


export GIT_TERMINAL_PROMPT=0

# 1. Attempt unauthenticated ls-remote first (works for public repositories)
set +e
ls_output="$(/usr/bin/git ls-remote -- "${repo_url}" 2>/dev/null)"
git_status="$?"
set -e

# 2. If unauthenticated check fails, retry with APPLICATION_REPOSITORY_TOKEN if configured
if [ "${git_status}" -ne 0 ]
then
        set +e
        REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN' 2>/dev/null)"
        set -e

        if [ -n "${REPOSITORY_TOKEN}" ] && [ "${REPOSITORY_TOKEN}" != "none" ]
        then
                encoded_auth="$(/usr/bin/printf '%s' "x-access-token:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"
                unset REPOSITORY_TOKEN

                if [ -z "${encoded_auth}" ]
                then
                        unset GIT_TERMINAL_PROMPT
                        status "Error: Failed to encode GitHub authentication header."
                        exit 1
                fi

                export GIT_CONFIG_COUNT=1
                export GIT_CONFIG_KEY_0="http.extraheader"
                export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

                set +e
                ls_output="$(/usr/bin/git ls-remote -- "${repo_url}" 2>/dev/null)"
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
        /bin/echo "none"
        exit 0
fi

if /bin/echo "${ls_output}" | /bin/grep -q 'HEAD'
then
        /bin/echo "full"
else
        /bin/echo "empty"
fi

exit 0


