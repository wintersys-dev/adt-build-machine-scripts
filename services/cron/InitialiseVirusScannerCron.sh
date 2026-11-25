#!/bin/sh
#: Name:        InitialiseVirusScannerCron.sh
#: Purpose:     Initialises a daily root crontab entry to run VirusScan.sh with a randomised delay and low priority.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseVirusScannerCron.sh
#:              InitialiseVirusScannerCron.sh [-h|--help]
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
#:   - ${BUILD_HOME}/helpers/security/VirusScan.sh
#:   - External binaries: cat, echo, grep, cut, printf, crontab, sleep, shuf, nice
#:
#: Exit Codes:
#:   0          Crontab entry verified or added successfully
#:   1          Missing configuration, missing target script/binaries, or crontab update failure
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

# Validate that the target virus scan script and required system utilities exist
scan_script="${BUILD_HOME}/helpers/security/VirusScan.sh"
if [ ! -f "${scan_script}" ] || [ ! -x "${scan_script}" ]
then
        status "Error: Target virus scan script missing or not executable at ${scan_script}"
        exit 1
fi

if [ ! -x /bin/sleep ] || [ ! -x /usr/bin/shuf ] || [ ! -x /usr/bin/nice ]
then
        status "Error: Required system binaries (/bin/sleep, /usr/bin/shuf, or /usr/bin/nice) missing or not executable."
        exit 1
fi

# Safely read the current root crontab (handles empty crontab without failing set -e)
set +e
current_crontab="$(/usr/bin/crontab -u root -l 2>/dev/null)"
set -e

matching_entry="$(/usr/bin/printf '%s\n' "${current_crontab}" | /usr/bin/grep -F "VirusScan.sh" || true)"

if [ -z "${matching_entry}" ]
then
        cron_entry="@daily /bin/sleep \$(/usr/bin/shuf -i1-1000 -n1) && /usr/bin/nice -n 15 ${scan_script}"
        if [ -z "${current_crontab}" ]
        then
                new_crontab="${cron_entry}"
        else
                new_crontab="$(/usr/bin/printf '%s\n%s' "${current_crontab}" "${cron_entry}")"
        fi

        if /usr/bin/printf '%s\n' "${new_crontab}" | /usr/bin/crontab -u root - 2>/dev/null
        then
                status "Success! Scheduled daily VirusScan.sh in root crontab."
        else
                status "Error: Failed to update root crontab for VirusScan.sh."
                exit 1
        fi
else
        status "VirusScan.sh is already present in root crontab."
fi

exit 0

