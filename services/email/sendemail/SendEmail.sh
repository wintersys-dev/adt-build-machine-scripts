#!/bin/sh
#: Name:        SendEmail.sh
#: Purpose:     Dispatches emails via the /usr/bin/sendemail CLI utility using configured SMTP providers.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       SendEmail.sh "<subject>" "<message>" "<to_address>" ["<content_type>"]
#:              SendEmail.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Email subject line (appended with current timestamp)
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
#:   - External binaries: cat, echo, grep, cut, date, sendemail
#:
#: Exit Codes:
#:   0          Email dispatched successfully via /usr/bin/sendemail
#:   1          Missing parameters, invalid provider, missing variables, or sendemail failure
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

# Retrieve SMTP provider settings and credentials
EMAIL_PROVIDER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_PROVIDER)"
FROM_ADDRESS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_FROM_EMAIL_ADDRESS)"
TO_ADDRESS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_TO_EMAIL_ADDRESS)"
USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_USERNAME)"
PASSWORD="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SYSTEM_EMAIL_PASSWORD)"

if [ -z "${EMAIL_PROVIDER}" ] || [ -z "${FROM_ADDRESS}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]
then
        status "Error: Failed to fetch required email configuration variables."
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

# Map configured provider ID to its SMTP relay endpoint
case "${EMAIL_PROVIDER}" in
        1)
                mailhub="smtp-pulse.com:2525"
                ;;
        2)
                mailhub="in-v3.mailjet.com:587"
                ;;
        3)
                mailhub="email-smtp.eu-west-1.amazonaws.com"
                ;;
        *)
                status "Error: Unsupported SYSTEM_EMAIL_PROVIDER value (${EMAIL_PROVIDER})."
                exit 1
                ;;
esac

# Set message content format option based on requested content type
if [ "${content_type}" = "HTML" ]
then
        msg_format="html"
else
        msg_format="text"
fi

# Dispatch the email via /usr/bin/sendemail
current_date="$(/bin/date)"

#can't hide credentials from process tree for sendemail

if ! /usr/bin/sendemail -o tls=yes -o "message-content-type=${msg_format}" -f "${FROM_ADDRESS}" -t "${TO_ADDRESS}" -s "${mailhub}" -xu "${USERNAME}" -xp "${PASSWORD}" -u "${subject} ${current_date}" -m "${message}"
then
        status "Error: Failed to send email via /usr/bin/sendemail."
        exit 1
fi

exit 0

	
