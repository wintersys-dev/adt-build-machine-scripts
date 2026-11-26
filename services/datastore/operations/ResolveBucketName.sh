#!/bin/sh
#: Name:        ResolveBucketName.sh
#: Purpose:     Resolves target S3 bucket naming topologies from a bucket classification type and optional specifier.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       ResolveBucketName.sh <bucket_type> [additional_specifier]
#:              ResolveBucketName.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target bucket classification type (e.g., ssl, config, asset, backup-web, backup-db, ad-hoc, all)
#:   $2         [Optional] Contextual tracking suffix or explicit bucket name for "ad-hoc" mode
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, fold, head, tr
#:
#: Exit Codes:
#:   0          Target bucket name resolved and printed to stdout
#:   1          Missing configuration, invalid arguments, or unsupported bucket type
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
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"  "${2}" 2>/dev/null
}

# Validate mandatory positional parameters
if [ -z "${1}" ]
then
        status "Error: ResolveBucketName.sh requires at least 1 argument (<bucket_type>)."
        exit 1
fi

bucket_type="${1}"
additional_specifier="${2}"

# Retrieve core deployment context variables
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
SSL_GENERATION_SERVICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSL_GENERATION_SERVICE)"

if [ -z "${WEBSITE_URL}" ] && [ "${bucket_type}" != "auth" ] && [ "${bucket_type}" != "ad-hoc" ] && [ "${bucket_type}" != "all" ]
then
        status "Error: Failed to fetch required context variable WEBSITE_URL."
        exit 1
fi

# Resolve config suffix: prefer explicit specifier if supplied, otherwise derive from SERVER_USER
config_suffix="${additional_specifier}"
if [ -z "${config_suffix}" ]
then
        SERVER_USER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SERVER_USER)"
        config_suffix="$(/bin/echo "${SERVER_USER}" | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]')"
fi

# Construct the target bucket name based on bucket classification
case "${bucket_type}" in
        "ssl")
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                else
                        status "Error: Unsupported or empty SSL_GENERATION_SERVICE '${SSL_GENERATION_SERVICE}'."
                        exit 1
                fi
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${DNS_CHOICE}-${service_token}-ssl"
                ;;
        "auth-ssl")
                AUTH_SERVER_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_SERVER_URL)"
                AUTH_DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_DNS_CHOICE)"
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                else
                        status "Error: Unsupported or empty SSL_GENERATION_SERVICE '${SSL_GENERATION_SERVICE}'."
                        exit 1
                fi
                active_bucket="adt-$(/bin/echo "${AUTH_SERVER_URL}" | /bin/sed 's/\./-/g')-${AUTH_DNS_CHOICE}-${service_token}-ssl"
                ;;
        "multi-region")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-multi-region"
                ;;
        "config")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}-config" | /bin/sed 's/\./-/g')-${config_suffix}"
                ;;
        "auth-config")
                AUTH_SERVER_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_SERVER_URL)"
                active_bucket="adt-$(/bin/echo "${AUTH_SERVER_URL}-config" | /bin/sed 's/\./-/g')-${config_suffix}"
                ;;
        "asset")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g')"
                ;;
        "scaling"|"backup-web")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "firewall-auth-laptop-ips"|"whitelist-auth-laptop-ips"|"firewall-emailed-links"|"whitelist-emailed-links"|"basic-auth-credentials")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${bucket_type}"
                ;;
        "wire-guard")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard"
                ;;
        "wire-guard-emails")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard-emails"
                ;;
        "wire-guard-emailed-links")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard-emailed-links"
                ;;
        "backup-webroot")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "backup-db")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-db-${additional_specifier}"
                ;;
        "auth")
                active_bucket="adt-authip-allowed-${additional_specifier}"
                ;;
        "dbaas")
                active_bucket="adt-$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${DNS_CHOICE}-dbaas"
                ;;
        "ad-hoc")
                active_bucket="adt-${additional_specifier}"
                ;;
        "all")
                active_bucket="all"
                ;;
        *)
                status "Error: Unknown bucket classification type '${bucket_type}'."
                exit 1
                ;;
esac

if [ -z "${active_bucket}" ]
then
        status "Error: Resolved target bucket name is empty for classification '${bucket_type}'."
        exit 1
fi

/bin/echo "${active_bucket}"
exit 0
