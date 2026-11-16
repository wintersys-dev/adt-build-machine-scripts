#!/bin/sh
#: Name:        InitialiseRenewSSLCertificateCron.sh
#: Purpose:     Initialises a commented-out root crontab entry for renewing SSL certificates and prompts interactive users.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseRenewSSLCertificateCron.sh
#:              InitialiseRenewSSLCertificateCron.sh [-h|--help]
#:
#: Parameters:
#:   None
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - IsHardcoreBuild.sh
#:   - ${BUILD_HOME}/initialisation/InitialiseNewSSLCertificate.sh
#:   - External binaries: cat, echo, grep, cut, printf, crontab
#:
#: Exit Codes:
#:   0          Crontab entry verified or added successfully
#:   1          Missing configuration, missing variables/scripts, or crontab update failure
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

# Validate that the target SSL initialisation script exists and is executable
ssl_script="${BUILD_HOME}/initialisation/InitialiseNewSSLCertificate.sh"
if [ ! -f "${ssl_script}" ] || [ ! -x "${ssl_script}" ]
then
        status "Error: Target SSL script missing or not executable at ${ssl_script}"
        exit 1
fi

# Retrieve required deployment context variables
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: Failed to fetch required context variables (CLOUDHOST or BUILD_IDENTIFIER)."
        exit 1
fi

# Safely read the current root crontab (handles empty crontab without failing set -e)
set +e
current_crontab="$(/usr/bin/crontab -u root -l 2>/dev/null)"
set -e

# Check if a matching SSL renewal entry already exists for this build and cloudhost
matching_entry="$(/usr/bin/printf '%s\n' "${current_crontab}" | /usr/bin/grep -F "InitialiseNewSSLCertificate.sh" | /usr/bin/grep -w "${BUILD_IDENTIFIER}" | /usr/bin/grep -w "${CLOUDHOST}" || true)"

if [ -z "${matching_entry}" ]
then
        cron_entry="#10 3 * * * export HARDCORE=\"1\" && ${ssl_script} \"none\" \"none\" \"${BUILD_IDENTIFIER}\" \"${CLOUDHOST}\""
        if [ -z "${current_crontab}" ]
        then
                new_crontab="${cron_entry}"
        else
                new_crontab="$(/usr/bin/printf '%s\n%s' "${current_crontab}" "${cron_entry}")"
        fi

        if /usr/bin/printf '%s\n' "${new_crontab}" | /usr/bin/crontab -u root - 2>/dev/null
        then
                status "Success! Scheduled commented-out InitialiseNewSSLCertificate.sh entry in root crontab."
                matching_entry="${cron_entry}"
        else
                status "Error: Failed to update root crontab for InitialiseNewSSLCertificate.sh."
                exit 1
        fi
else
        status "InitialiseNewSSLCertificate.sh entry for ${BUILD_IDENTIFIER} (${CLOUDHOST}) is already present in root crontab."
fi

# In non-hardcore (interactive) builds, notify the user if the SSL renewal cron job is commented out
is_hardcore="$("${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh" 2>/dev/null || true)"

if [ "${is_hardcore}" != "1" ]
then
        commented_entry="$(/usr/bin/printf '%s\n' "${matching_entry}" | /usr/bin/grep "^#" || true)"
        if [ -n "${commented_entry}" ]
        then
                status "Please note: the Initialise New SSL Certificate cronjob is currently commented out. If you want to enable SSL certificate renewal when they expire please uncomment the line shown below in your crontab"
                status "${commented_entry}"
                if [ -t 0 ]
                then
                        status "Press <enter> to continue"
                        read -r _
                fi
        fi
fi

exit 0

        
