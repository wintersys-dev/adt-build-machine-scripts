#!/bin/sh
#: Name:        SendEmail.sh
#: Purpose:     Configures ssmtp on first run and dispatches emails via /usr/bin/mail.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       SendEmail.sh "<subject>" "<message>" "<to_address>" ["<content_type>"]
#:              SendEmail.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Email subject line
#:   $2         [Required] Email body message
#:   $3         [Required] Recipient email address or "system" alias
#:   $4         [Optional] Content type ("default" or "HTML")
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, mkdir, touch, chmod, mail
#:
#: Exit Codes:
#:   0          Email dispatched successfully via ssmtp/mail
#:   1          Missing parameters, missing configuration variables, or mail delivery failure
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
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Minimum of 3 arguments required."
        status "Usage: $0 <subject> <message> <to_address> [content_type]"
        exit 1
fi

subject="${1}"
message="${2}"
to_address="${3}"
content_type="${4}"

# Retrieve SMTP provider settings and deployment context variables
EMAIL_PROVIDER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_PROVIDER)"
FROM_ADDRESS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_FROM_EMAIL_ADDRESS)"
TO_ADDRESS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_TO_EMAIL_ADDRESS)"
FROM_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_DISPLAY_NAME | /usr/bin/sed 's/_/ /g')"
USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_USERNAME)"
PASSWORD="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_PASSWORD)"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${EMAIL_PROVIDER}" ] || [ -z "${FROM_ADDRESS}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: Failed to fetch required email or deployment context variables."
        exit 1
fi

# Override default system recipient if an explicit address was supplied
if [ "${to_address}" != "system" ]
then
        TO_ADDRESS="${to_address}"
fi

if [ -z "${TO_ADDRESS}" ]
then
        status "Error: Target recipient email address resolved empty."
        exit 1
fi

if [ "${content_type}" = "default" ]
then
        content_type=""
fi

# Ensure the runtime directory exists for tracking ssmtp initialization state
runtime_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

# Configure /etc/ssmtp/ssmtp.conf once per build deployment
ssmtp_flag="${runtime_dir}/SSMTP_INITIALISED"
ssmtp_conf="/etc/ssmtp/ssmtp.conf"

if [ ! -f "${ssmtp_flag}" ]
then
        case "${EMAIL_PROVIDER}" in
                1)
                        mailhub="smtp-pulse.com:2525"
                        ;;
                2)
                        mailhub="in-v3.mailjet.com:587"
                        ;;
                3)
                        mailhub="email-smtp.eu-west-1.amazonaws.com:587"
                        ;;
                *)
                        status "Error: Unsupported SYSTEM_EMAIL_PROVIDER value (${EMAIL_PROVIDER})."
                        exit 1
                        ;;
        esac

        {
                /bin/echo "mailhub=${mailhub}"
                /bin/echo "AuthUser=${USERNAME}"
                /bin/echo "AuthPass=${PASSWORD}"
                /bin/echo "FromLineOverride=YES"
                /bin/echo "UseSTARTTLS=YES"
        } > "${ssmtp_conf}"

        /bin/chmod 600 "${ssmtp_conf}"
        /bin/touch "${ssmtp_flag}"
fi

# Dispatch the email using /usr/bin/mail with appropriate headers
if [ "${content_type}" = "HTML" ]
then
        if ! /bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "Content-Type: text/html" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}" 
        then
                status "Error: Failed to send HTML email via /usr/bin/mail."
                exit 1
        fi
else
        if ! /bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}"
        then
                status "Error: Failed to send plain-text email via /usr/bin/mail."
                exit 1
        fi
fi

exit 0

