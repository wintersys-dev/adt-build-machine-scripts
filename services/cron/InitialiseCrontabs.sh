#!/bin/sh
#: Name:        InitialiseBuildMachineCrontabs.sh
#: Purpose:     Orchestrates the initialisation of all required root crontab entries for the Build Machine.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseBuildMachineCrontabs.sh
#:              InitialiseBuildMachineCrontabs.sh [-h|--help]
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
#:   - InitialiseBuildMachineFirewallCron.sh
#:   - InitialiseUpdateAndUpgradeCron.sh
#:   - InitialiseRenewSSLCertificateCron.sh
#:   - InitialiseAuditSSHConnectionsCron.sh
#:   - InitialiseVirusScannerCron.sh
#:   - External binaries: cat, echo, grep, cut, touch, chmod, chown
#:
#: Exit Codes:
#:   0          All build machine crontab initialisers executed successfully
#:   1          Missing configuration, missing/non-executable cron initialiser, or execution failure
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

# Ensure the root crontab spool file exists with strict ownership and permissions
root_crontab="/var/spool/cron/crontabs/root"
if [ ! -f "${root_crontab}" ]
then
        /bin/touch "${root_crontab}"
        /bin/chown root:crontab "${root_crontab}" 2>/dev/null || /bin/chown root:root "${root_crontab}"
        /bin/chmod 600 "${root_crontab}"
fi

# Execute each build machine cron initialiser script sequentially with validation
cron_dir="${BUILD_HOME}/services/cron"
cron_scripts="InitialiseBuildMachineFirewallCron.sh InitialiseUpdateAndUpgradeCron.sh InitialiseRenewSSLCertificateCron.sh InitialiseAuditSSHConnectionsCron.sh InitialiseVirusScannerCron.sh"

for script_name in ${cron_scripts}
do
        script_path="${cron_dir}/${script_name}"
        if [ ! -f "${script_path}" ] || [ ! -x "${script_path}" ]
        then
                status "Error: Cron initialiser script missing or not executable at ${script_path}"
                exit 1
        fi

        status "Initialising cron job via ${script_name}..."
        "${script_path}"
done

status "Success! All Build Machine crontabs initialised."
exit 0

