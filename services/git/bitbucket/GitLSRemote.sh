#!/bin/sh
#: Name:        GitLSRemote.sh
#: Purpose:     Checks whether a Bitbucket repository exists and resolves its HEAD reference via git ls-remote.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       GitLSRemote.sh "<repository_ownername>" "<repository_name>" ["<repository_username>"]
#:              GitLSRemote.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Bitbucket workspace or account namespace
#:   $2         [Required] Case-sensitive slug/name of the target Bitbucket repository
#:   $3         [Optional] Bitbucket username associated with REPOSITORY_TOKEN (defaults to x-token-auth)
#:
#: Environment:
#:   BUILD_HOME       Resolved automatically from /home/buildhome.dat
#:   REPOSITORY_TOKEN Optional Bitbucket access token or app password for private repository authentication
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, chmod, rm, git
#:
#: Exit Codes:
#:   0          Remote repository exists and HEAD reference found
#:   1          Missing required arguments, missing config file, or git ls-remote failure
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

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: 2 arguments are required and 1 optional argument."
        status "Usage: $0 <repository_ownername> <repository_name> [repository_username]"
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"
repository_username="${3}"

# Construct temporary .netrc with restricted permissions and guaranteed cleanup on exit
netrc_file="${HOME}/.netrc"
trap '/bin/rm -f "${netrc_file}"' EXIT

if [ -n "${REPOSITORY_TOKEN}" ]
then
        if [ -z "${repository_username}" ]
        then
                repository_username="x-token-auth"
        fi

        (
                umask 077
                /bin/cat << EOF > "${netrc_file}"
machine bitbucket.org
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF
        )
        /bin/chmod 600 "${netrc_file}"
fi

# Assemble Bitbucket repository URL from split components
git_host="bitbucket.org"
repo_url="https://${git_host}/${repository_ownername}/${repository_name}.git"

# Perform remote repository lookup and capture exit code safely
set +e
remote_refs="$(/usr/bin/git ls-remote "${repo_url}" 2>/dev/null)"
error_code="$?"
set -e

/bin/rm -f "${netrc_file}"

if [ "${error_code}" -ne 0 ]
then
        status "Error: git ls-remote exited with error code ${error_code}."
        exit 1
fi

if ! /bin/echo "${remote_refs}" | /usr/bin/grep -q 'HEAD'
then
        status "Error: No HEAD reference found for ${repository_ownername}/${repository_name} on Bitbucket."
        exit 1
fi

/bin/echo "${remote_refs}" | /usr/bin/grep 'HEAD'

exit 0
