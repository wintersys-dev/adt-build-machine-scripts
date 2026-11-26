#!/bin/sh
#: Name:        ProvisionAndArrangeSSLCertificate.sh
#: Purpose:     Coordinates manual SSL/TLS certificate verification, rotation, and installation on the build machine.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ProvisionAndArrangeSSLCertificate.sh [website_url]
#:              ProvisionAndArrangeSSLCertificate.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Target domain name (defaults to WEBSITE_URL from build configuration)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat and exported
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - ${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh
#:   - ${BUILD_HOME}/services/security/ssl/manual/ObtainSSLCertificate.sh
#:   - External binaries: cat, echo, grep, cut, date, mkdir, mv, chmod, openssl, touch
#:
#: Exit Codes:
#:   0          Valid manual SSL/TLS certificate verified or installed in build runtime cache
#:   1          Missing /home/buildhome.dat, missing required variables/helpers, or installation failure
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

# Resolve the build machine toolkit root directory from /home/buildhome.dat
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
        export BUILD_HOME
else
        /bin/echo "Application build configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

if [ -z "${BUILD_HOME}" ] || [ ! -d "${BUILD_HOME}" ]
then
        /bin/echo "Error: Resolved BUILD_HOME directory '${BUILD_HOME}' is invalid." >&2
        exit 1
fi

var_helper="${BUILD_HOME}/helpers/services/GetVariableValue.sh"
log_helper="${BUILD_HOME}/helpers/services/LogStatusMessages.sh"
hardcore_helper="${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh"
obtain_script="${BUILD_HOME}/services/security/ssl/manual/ObtainSSLCertificate.sh"

if [ ! -x "${var_helper}" ] || [ ! -x "${obtain_script}" ]
then
        /bin/echo "Error: Required SSL/build helper scripts missing or not executable under ${BUILD_HOME}." >&2
        exit 1
fi

status()
{
        if [ -x "${log_helper}" ]
        then
                "${log_helper}" "${1}"
        else
                /bin/echo "${1}"
        fi
}

target_domain="${1}"

set +e
CLOUDHOST="$("${var_helper}" 'CLOUDHOST')"
BUILD_IDENTIFIER="$("${var_helper}" 'BUILD_IDENTIFIER')"
DNS_CHOICE="$("${var_helper}" 'DNS_CHOICE')"

if [ -z "${target_domain}" ]
then
        target_domain="$("${var_helper}" 'WEBSITE_URL')"
fi
set -e

if [ -z "${target_domain}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Missing required SSL context variables (target_domain, CLOUDHOST, BUILD_IDENTIFIER, or DNS_CHOICE)." >&2
        exit 1
fi

ssl_cache_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${target_domain}"
cached_cert="${ssl_cache_dir}/fullchain.pem"
cached_key="${ssl_cache_dir}/privkey.pem"

if [ ! -d "${ssl_cache_dir}" ]
then
        /bin/mkdir -p "${ssl_cache_dir}"
fi

status ""
status "#############################################################################################"
status "We are setting up an SSL certificate for ${target_domain} so it can establish secure connections"
status "#############################################################################################"

needs_install="no"
install_reason=""

if [ -f "${cached_cert}" ] && [ -f "${cached_key}" ]
then
        # Check if cached certificate expires within 7 days (604800 seconds); returns non-zero if expiring/expired
        if ! /usr/bin/openssl x509 -checkend 604800 -noout -in "${cached_cert}" >/dev/null 2>&1
        then
                timestamp="$(/bin/date +%Y%m%d%H%M%S)"
                /bin/mv "${cached_cert}" "${cached_cert}.previous-${timestamp}"
                /bin/mv "${cached_key}" "${cached_key}.previous-${timestamp}"
                needs_install="yes"
                install_reason="because the old certificate has expired or is expiring soon"
        fi
else
        needs_install="yes"
        install_reason="because originally there was no certificate present on your filesystem for me to use"
fi

if [ "${needs_install}" = "yes" ]
then
        set +e
        "${obtain_script}" "${target_domain}"
        obtain_exit="$?"
        set -e

        if [ "${obtain_exit}" -eq 0 ] && [ -f "${cached_cert}" ] && [ -f "${cached_key}" ]
        then
                /bin/chmod 400 "${cached_key}" "${cached_cert}"
                status "Have successfully installed a new certificate for your domain ${target_domain} ${install_reason}"
                status "Press <enter> to acknowledge"
                if [ -x "${hardcore_helper}" ] && [ "$("${hardcore_helper}")" != "1" ]
                then
                        read -r _
                fi
        else
                status "Something seems to be a bit wrong. We were trying to install a new SSL certificate for ${target_domain}, but it doesn't seem to have been generated"
                status "Can't operate without it, this is a secure system, so have to exit. Please investigate in ${BUILD_HOME}/logs"
                /usr/bin/touch /tmp/END_IT_ALL
                exit 1
        fi
fi

exit 0

