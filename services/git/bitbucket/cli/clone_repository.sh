!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Performs a shallow Git clone from Bitbucket using secure env headers.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       clone_repository.sh <branch> <repository_ownername> <repository_name> <destination_directory>
#:
#: Parameters:
#:   $1         [Required] Target branch name or "--branch <name>" flag.
#:   $2         [Required] The Bitbucket workspace or repository owner name.
#:   $3         [Required] The name/slug of the repository to clone.
#:   $4         [Required] Local destination directory for the cloned repository.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - External binaries: base64, cat, echo, git, printf, sed
#:
#: Exit Codes:
#:   0          Repository cloned cleanly into destination directory
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

# Strip optional "--branch " prefix so both "main" and "--branch main" inputs work cleanly
branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh 'APPLICATION_REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] 
then
        status "Error: Failed to fetch required context variable APPLICATIONREPOSITORYTOKEN ."
        exit 1
fi

encoded_auth="$(/usr/bin/printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"
unset REPOSITORY_TOKEN

if [ -z "${encoded_auth}" ]
then
        status "Error: Failed to encode Bitbucket authentication header."
        exit 1
fi

# Export transient Git HTTP header configuration to avoid exposing tokens in process trees
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.extraheader"
export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

set +e
/usr/bin/git clone \
        --depth 1 \
        --branch "${branch}" \
        -- "https://bitbucket.org/${repository_ownername}/${repository_name}.git" \
        "${destination_directory}" >&2
git_status="$?"
set -e

# Immediately scrub sensitive environment variables
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 encoded_auth REPOSITORY_TOKEN

if [ "${git_status}" -ne 0 ]
then
        status "Error: Git clone failed for ${repository_ownername}/${repository_name} on branch ${branch} (exit code: ${git_status})."
        exit "${git_status}"
fi

/bin/echo "${destination_directory}"
exit 0
