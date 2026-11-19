#!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Performs a branch-specific shallow Git clone from GitLab using secure env headers.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       clone_repository.sh <branch> <repository_ownername> <repository_name> <destination_directory>
#:              clone_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target branch name or "--branch <name>" flag.
#:   $2         [Required] The GitLab username or group path (repository owner).
#:   $3         [Required] The name/slug of the GitLab project to clone.
#:   $4         [Required] Local destination directory path to clone into.
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: base64, cat, cut, echo, git, grep, printf, sed
#:
#: Exit Codes:
#:   0          Project branch cloned cleanly into destination directory
#:   1          Missing arguments, layout faults, or missing credentials
#:   *          Bubbled non-zero exit code from git clone
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: Branch, repository owner, repository name, and destination directory are required." 
        status "Usage: $0 <branch> <repository_ownername> <repository_name> <destination_directory>"
        exit 1
fi

branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN)." 
        exit 1
fi

# GitLab HTTPS uses oauth2:<token> for Basic Auth
encoded_auth="$(/usr/bin/printf '%s' "oauth2:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"
unset REPOSITORY_TOKEN

if [ -z "${encoded_auth}" ]
then
        status "Error: Failed to encode GitLab authentication header." 
        exit 1
fi

git_base="https://gitlab.com"
repo_url="${git_base}/${repository_ownername}/${repository_name}.git"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.extraheader"
export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"
export GIT_TERMINAL_PROMPT=0

set +e
/usr/bin/git clone \
        --depth 1 \
        --branch "${branch}" \
        -- "${repo_url}" \
        "${destination_directory}" >&2
git_status="$?"
set -e

unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_TERMINAL_PROMPT encoded_auth

if [ "${git_status}" -ne 0 ]
then
        status "Error: git clone exited with error code ${git_status}." 
        exit "${git_status}"
fi

/bin/echo "${destination_directory}"
exit 0
