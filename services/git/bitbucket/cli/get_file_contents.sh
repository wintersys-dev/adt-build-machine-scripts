#!/bin/sh
#: Name:        get_file_contents.sh
#: Purpose:     Retrieves the raw contents of a single file from a Bitbucket Git repository via Git CLI (public first, authenticated fallback).
#: Author:      Peter Winter
#: Date:        21/11/2026
#: Version:     1.0
#:
#: Usage:       get_file_contents.sh <repository_name> <repository_ownername> <file_path> [branch_or_ref]
#:              get_file_contents.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The name/slug of the repository to inspect.
#:   $2         [Required] The Bitbucket workspace or repository owner name.
#:   $3         [Required] The path to the file within the repository (e.g., dbp.dat or src/main.sh).
#:   $4         [Optional] Branch or tag name (defaults to repository default branch if omitted).
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - External binaries: base64, cat, cut, echo, git, grep, mktemp, printf, rm, sed, tr
#:
#: Exit Codes:
#:   0          Raw file contents printed to stdout
#:   1          Missing arguments, layout faults, authentication error, network failure, or file/repo not found
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
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Repository name, repository ownername, and file path arguments are required."
        status "Usage: $0 <repository_name> <repository_ownername> <file_path> [branch_or_ref]"
        exit 1
fi

repository_name="${1}"
repository_ownername="${2}"
file_path="$(/bin/echo "${3}" | /usr/bin/sed 's|^/||')"
git_ref="${4}"

repo_url="https://bitbucket.org{repository_ownername}/${repository_name}.git"

tmp_repo="$(/bin/mktemp -d /tmp/bb_github_file.XXXXXX)"

cleanup() {
        unset GIT_TERMINAL_PROMPT GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
        /bin/rm -rf "${tmp_repo}"
}
trap cleanup EXIT INT TERM

export GIT_TERMINAL_PROMPT=0

git_err=""

fetch_and_print_file() {
        /bin/rm -rf "${tmp_repo:?}"/* "${tmp_repo:?}"/.[!.]* 2>/dev/null || true

        if [ -n "${git_ref}" ]
        then
                git_err="$(/usr/bin/git clone --depth 1 --filter=blob:none --no-checkout --branch "${git_ref}" -- "${repo_url}" "${tmp_repo}" 2>&1 >/dev/null)" || return 1
        else
                git_err="$(/usr/bin/git clone --depth 1 --filter=blob:none --no-checkout -- "${repo_url}" "${tmp_repo}" 2>&1 >/dev/null)" || return 1
        fi

        /usr/bin/git -C "${tmp_repo}" show "HEAD:${file_path}" 2>/dev/null || return 2
        return 0
}

# 1. Attempt unauthenticated fetch first
set +e
fetch_and_print_file
fetch_status="$?"
set -e

# 2. If unauthenticated clone fails (status 1), retry with Bitbucket Basic Auth header
if [ "${fetch_status}" -eq 1 ]
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
                        status "Error: Failed to encode Bitbucket authentication header."
                        exit 1
                fi

                export GIT_CONFIG_COUNT=1
                export GIT_CONFIG_KEY_0="http.extraheader"
                export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

                set +e
                fetch_and_print_file
                fetch_status="$?"
                set -e

                unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 encoded_auth
        else
                unset REPOSITORY_TOKEN
        fi
fi

if [ "${fetch_status}" -eq 0 ]
then
        exit 0
elif [ "${fetch_status}" -eq 2 ]
then
        status "Error: File '${file_path}' not found in ${repository_ownername}/${repository_name}."
        exit 1
else
        status "Error: git clone failed for ${repository_ownername}/${repository_name}: ${git_err}"
        exit 1
fi
