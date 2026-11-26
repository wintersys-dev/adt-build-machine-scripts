#!/bin/sh
#: Name:        ObtainSSLCertificate.sh
#: Purpose:     Issues an SSL/TLS certificate via the lego ACME client using DNS-01 challenges on the build machine.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ObtainSSLCertificate.sh [website_url] [auth: yes|no]
#:              ObtainSSLCertificate.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Target domain name (defaults to WEBSITE_URL from build configuration)
#:   $2         [Optional] Set to "yes" to issue using AUTH_SERVER_URL and AUTH_DNS_* credentials
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat and exported
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/helpers/services/GetVariableValue.sh
#:   - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh
#:   - ${BUILD_HOME}/installation/InstallLego.sh
#:   - ${BUILD_HOME}/services/dns/GetZoneID.sh
#:   - ${BUILD_HOME}/services/dns/CreateZone.sh
#:   - /usr/bin/lego
#:   - External binaries: cat, echo, printf, grep, cut, awk, mkdir, cp, find, readlink, touch
#:
#: Exit Codes:
#:   0          SSL/TLS certificate issued cleanly by lego
#:   1          Missing /home/buildhome.dat, missing required variables/helpers, or issuance failure
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

if [ ! -x "${var_helper}" ]
then
        /bin/echo "Error: GetVariableValue.sh missing or not executable at ${var_helper}" >&2
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

website_url="${1}"
auth="${2}"

set +e
BUILDOS="$("${var_helper}" 'BUILDOS')"
DNS_CHOICE="$("${var_helper}" 'DNS_CHOICE')"
SSL_LIVE_CERT="$("${var_helper}" 'SSL_LIVE_CERT')"
DNS_USERNAME="$("${var_helper}" 'DNS_USERNAME')"
DNS_SECURITY_KEY="$("${var_helper}" 'DNS_SECURITY_KEY')"
SSL_GENERATION_METHOD="$("${var_helper}" 'SSL_GENERATION_METHOD')"
SSL_GENERATION_SERVICE="$("${var_helper}" 'SSL_GENERATION_SERVICE')"

if [ -n "${website_url}" ]
then
        WEBSITE_URL="${website_url}"
else
        WEBSITE_URL="$("${var_helper}" 'WEBSITE_URL')"
fi

if [ "${auth}" = "yes" ]
then
        WEBSITE_URL="$("${var_helper}" 'AUTH_SERVER_URL')"
        DNS_USERNAME="$("${var_helper}" 'AUTH_DNS_USERNAME')"
        DNS_SECURITY_KEY="$("${var_helper}" 'AUTH_DNS_SECURITY_KEY')"
        DNS_CHOICE="$("${var_helper}" 'AUTH_DNS_CHOICE')"
fi
set -e

if [ -z "${WEBSITE_URL}" ] || [ -z "${DNS_CHOICE}" ] || [ -z "${BUILDOS}" ]
then
        /bin/echo "Error: Missing required SSL/DNS context variables (WEBSITE_URL, DNS_CHOICE, or BUILDOS)." >&2
        exit 1
fi

export GOROOT=/usr/local/go
export GOPATH="${HOME}"
export PATH="${GOPATH}/bin:${GOROOT}/bin:${PATH}"

if [ ! -x /usr/bin/lego ]
then
        "${BUILD_HOME}/installation/InstallLego.sh" "${BUILDOS}"
fi

if [ ! -x /usr/bin/lego ]
then
        /bin/echo "Error: /usr/bin/lego not found or not executable after installation." >&2
        exit 1
fi

lego_dir="${BUILD_HOME}/.lego"
if [ ! -d "${lego_dir}/accounts" ]
then
        /bin/mkdir -p "${lego_dir}/accounts"
fi
if [ ! -d "${lego_dir}/certificates" ]
then
        /bin/mkdir -p "${lego_dir}/certificates"
fi

server_flag=""
if [ "${SSL_GENERATION_METHOD}" = "AUTOMATIC" ] && [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
then
        if [ "${SSL_LIVE_CERT}" = "0" ]
        then
                server_flag="--server=https://letsencrypt.org"
        fi
elif [ "${SSL_GENERATION_METHOD}" = "AUTOMATIC" ] && [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
then
        server_flag="--server=https://zerossl.com"
fi

cleanup_dns_env()
{
        unset CLOUDFLARE_DNS_API_TOKEN CF_API_EMAIL CF_API_KEY \
              DO_AUTH_TOKEN DO_POLLING_INTERVAL DO_PROPAGATION_TIMEOUT \
              EXOSCALE_API_KEY EXOSCALE_API_SECRET EXOSCALE_POLLING_INTERVAL EXOSCALE_PROPAGATION_TIMEOUT \
              LINODE_TOKEN LINODE_POLLING_INTERVAL LINODE_PROPAGATION_TIMEOUT LINODE_HTTP_TIMEOUT \
              VULTR_API_KEY VULTR_POLLING_INTERVAL VULTR_PROPAGATION_TIMEOUT LEGO_DISABLE_CNAME_SUPPORT
}
trap cleanup_dns_env EXIT INT TERM

status "Generating new SSL certificate for the ${DNS_CHOICE} DNS service"

case "${DNS_CHOICE}" in
        cloudflare)
                zone_name="$(printf '%s\n' "${WEBSITE_URL}" | /usr/bin/cut -d'.' -f2-)"
                set +e
                zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"
                set -e

                if [ -z "${zone_id}" ]
                then
                        "${BUILD_HOME}/services/dns/CreateZone.sh" "${WEBSITE_URL}"
                fi

                case "${DNS_SECURITY_KEY}" in
                        *:::*)
                                cloudflare_dns_api_token="$(printf '%s\n' "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
                                export CLOUDFLARE_DNS_API_TOKEN="${cloudflare_dns_api_token}"
                                ;;
                        *)
                                export CF_API_EMAIL="${DNS_USERNAME}"
                                export CF_API_KEY="${DNS_SECURITY_KEY}"
                                ;;
                esac
                ;;
        digitalocean)
                export DO_AUTH_TOKEN="${DNS_SECURITY_KEY}"
                export DO_POLLING_INTERVAL=30
                export DO_PROPAGATION_TIMEOUT=600
                ;;
        exoscale)
                export EXOSCALE_API_KEY="$(printf '%s\n' "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':' '{print $1}')"
                export EXOSCALE_API_SECRET="$(printf '%s\n' "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':' '{print $2}')"
                export EXOSCALE_POLLING_INTERVAL=30
                export EXOSCALE_PROPAGATION_TIMEOUT=600
                ;;
        linode)
                export LINODE_TOKEN="${DNS_SECURITY_KEY}"
                export LINODE_POLLING_INTERVAL=30
                export LINODE_PROPAGATION_TIMEOUT=600
                export LINODE_HTTP_TIMEOUT=120
                ;;
        vultr)
                export VULTR_API_KEY="${DNS_SECURITY_KEY}"
                export VULTR_POLLING_INTERVAL=30
                export VULTR_PROPAGATION_TIMEOUT=600
                export LEGO_DISABLE_CNAME_SUPPORT=true
                ;;
        *)
                /bin/echo "Error: Unsupported DNS_CHOICE '${DNS_CHOICE}'." >&2
                exit 1
                ;;
esac

issuer_cert="${lego_dir}/certificates/${WEBSITE_URL}.issuer.crt"
issued="no"

if [ ! -f "${issuer_cert}" ] || [ -z "$(/usr/bin/find "${issuer_cert}" -mmin -5 2>/dev/null)" ]
then
        status "Please wait, valid certificate not found, trying to issue SSL certificate for your domain ${WEBSITE_URL}"

        count=1
        while [ "${count}" -le 5 ]
        do
                status "Attempting to generate SSL Certificate, this is attempt ${count} of 5"

                set +e
                /usr/bin/lego --path "${lego_dir}" run \
                        --email "${DNS_USERNAME}" \
                        --domains "${WEBSITE_URL}" \
                        --dns "${DNS_CHOICE}" \
                        ${server_flag} \
                        --cert.timeout 120 \
                        --dns.resolvers '1.1.1.1:53,8.8.8.8:53' \
                        --accept-tos
                lego_exit="$?"
                set -e

                if [ -L /usr/bin/lego ] && [ "$(/usr/bin/readlink -f /usr/bin/lego)" = "/snap/bin/lego" ]
                then
                        snap_cert_dir="/var/snap/lego/common/.lego/certificates"
                        if [ -f "${snap_cert_dir}/${WEBSITE_URL}.issuer.crt" ]
                        then
                                /bin/cp "${snap_cert_dir}/${WEBSITE_URL}.issuer.crt" "${lego_dir}/certificates/${WEBSITE_URL}.issuer.crt"
                                /bin/cp "${snap_cert_dir}/${WEBSITE_URL}.crt" "${lego_dir}/certificates/${WEBSITE_URL}.crt"
                                /bin/cp "${snap_cert_dir}/${WEBSITE_URL}.key" "${lego_dir}/certificates/${WEBSITE_URL}.key"
                        fi
                fi

                if [ "${lego_exit}" -eq 0 ] && [ -n "$(/usr/bin/find "${issuer_cert}" -mmin -5 2>/dev/null)" ]
                then
                        issued="yes"
                        break
                fi

                count=$((count + 1))
        done
else
        issued="yes"
fi

cleanup_dns_env
trap - EXIT INT TERM

if [ "${issued}" != "yes" ]
then
        status "FAILED TO ISSUE SSL CERTIFICATE (what is SSL_LIVE_CERT set to and have you hit an issuance limit for ${WEBSITE_URL}?)"
        status "Will have to exit, can't continue without the SSL certificate being set up"
        /usr/bin/touch /tmp/END_IT_ALL
        exit 1
fi

exit 0

