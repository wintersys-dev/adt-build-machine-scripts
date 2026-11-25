#!/bin/sh
#: Name:        InitialiseUpdateAndUpgradeCron.sh
#: Purpose:     Initialises a daily root crontab entry to update and upgrade system packages via apt and reboot.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseUpdateAndUpgradeCron.sh
#:              InitialiseUpdateAndUpgradeCron.sh [-h|--help]
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
#:   - External binaries: cat, echo, grep, cut, printf, crontab, apt, shutdown
#:
#: Exit Codes:
#:   0          Crontab entry verified or added successfully
#:   1          Missing configuration, missing required system binaries, or crontab update failure
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

# Validate that required system binaries exist and are executable
if [ ! -x /usr/bin/apt ] || [ ! -x /usr/sbin/shutdown ]
then
        status "Error: Required system binaries (/usr/bin/apt or /usr/sbin/shutdown) missing or not executable."
        exit 1
fi

# Safely read the current root crontab (handles empty crontab without failing set -e)
set +e
current_crontab="$(/usr/bin/crontab -u root -l 2>/dev/null)"
set -e

# Check if an apt update/upgrade job is already scheduled; if not, append and reload via stdin
matching_entry="$(/usr/bin/printf '%s\n' "${current_crontab}" | /usr/bin/grep -F "apt" | /usr/bin/grep -F "update" | /usr/bin/grep -F "upgrade" || true)"

if [ -z "${matching_entry}" ]
then
        cron_entry="45 4 * * * /usr/bin/apt -y -qq update && /usr/bin/apt -y -qq upgrade && /usr/sbin/shutdown -r now"
        if [ -z "${current_crontab}" ]
        then
                new_crontab="${cron_entry}"
        else
                new_crontab="$(/usr/bin/printf '%s\n%s' "${current_crontab}" "${cron_entry}")"
        fi
else
        status "An apt update and upgrade job is already present in root crontab."
fi

if /usr/bin/printf '%s\n' "${new_crontab}" | /usr/bin/crontab -u root - 2>/dev/null
then
        status "Success! Scheduled daily apt update/upgrade and reboot in root crontab."
else
        status "Error: Failed to update root crontab for apt update/upgrade."
        exit 1
fi

exit 0

