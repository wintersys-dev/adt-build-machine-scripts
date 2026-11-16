#!/bin/sh
#: Name:        InitialiseAuditSSHConnectionsCrontab.sh
#: Purpose:     Initialises a root crontab entry to run AuditSSHConnections.sh every minute.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseAuditSSHConnectionsCrontab.sh
#:              InitialiseAuditSSHConnectionsCrontab.sh [-h|--help]
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
#:   - ${BUILD_HOME}/helpers/security/AuditSSHConnections.sh
#:   - External binaries: cat, echo, grep, cut, crontab
#:
#: Exit Codes:
#:   0          Crontab entry verified or added successfully
#:   1          Missing configuration, missing target script, or crontab update failure
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

# Validate that the target audit script exists and is executable
audit_script="${BUILD_HOME}/helpers/security/AuditSSHConnections.sh"
if [ ! -f "${audit_script}" ] || [ ! -x "${audit_script}" ]
then
        status "Error: Target script missing or not executable at ${audit_script}"
        exit 1
fi

# Safely read the current root crontab (handles empty crontab without failing set -e)
set +e
current_crontab="$(/usr/bin/crontab -u root -l 2>/dev/null)"
set -e

# Check if the audit job is already scheduled; if not, append and reload safely via stdin
if ! /bin/echo "${current_crontab}" | /usr/bin/grep -Fq "AuditSSHConnections.sh"
then
        cron_entry="*/1 * * * * ${audit_script}"
        if [ -z "${current_crontab}" ]
        then
                new_crontab="${cron_entry}"
        else
                new_crontab="$(/usr/bin/printf '%s\n%s' "${current_crontab}" "${cron_entry}")"
        fi

        fi

        if /bin/echo "${new_crontab}" | /usr/bin/crontab -u root - 2>/dev/null
        then
                status "Success! Scheduled AuditSSHConnections.sh in root crontab."
        else
                status "Error: Failed to update root crontab for AuditSSHConnections.sh."
                exit 1
        fi
else
        status "AuditSSHConnections.sh is already present in root crontab."
fi

exit 0

