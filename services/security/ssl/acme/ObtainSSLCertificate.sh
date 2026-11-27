#!/bin/sh
#: Name:        ObtainSSLCertificate.sh
#: Purpose:     Issues an SSL/TLS certificate via acme.sh DNS-01 challenge with CA failover on the build machine.
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
#:   - ${BUILD_HOME}/installation/InstallSocat.sh
#:   - ${BUILD_HOME}/installation/InstallAcme.sh
#:   - ${BUILD_HOME}/services/dns/GetZoneID.sh
#:   - ${BUILD_HOME}/services/dns/CreateZone.sh
#:   - ${BUILD_HOME}/services/security/ssl/acme/acme-overrides/*
#:   - ${HOME}/.acme.sh/acme.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, cp, rm
#:
#: Exit Codes:
#:   0          SSL/TLS certificate issued cleanly by primary or backup ACME CA
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
if [ ! -x "${var_helper}" ]
then
        /bin/echo "Error: GetVariableValue.sh missing or not executable at ${var_helper}" >&2
        exit 1
fi

website_url="${1}"
auth="${2}"

set +e
SYSTEM_FROM_EMAIL_ADDRESS="$("${var_helper}" 'SYSTEM_FROM_EMAIL_ADDRESS')"
DNS_USERNAME="$("${var_helper}" 'DNS_USERNAME')"
DNS_SECURITY_KEY="$("${var_helper}" 'DNS_SECURITY_KEY')"
DNS_CHOICE="$("${var_helper}" 'DNS_CHOICE')"
BUILDOS="$("${var_helper}" 'BUILDOS')"
SSL_GENERATION_SERVICE="$("${var_helper}" 'SSL_GENERATION_SERVICE')"
SSL_LIVE_CERT="$("${var_helper}" 'SSL_LIVE_CERT')"

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
        /bin/echo "Error: Missing required SSL/DNS configuration values (WEBSITE_URL, DNS_CHOICE, or BUILDOS)." >&2
        exit 1
fi

server="letsencrypt"
backup_server="zerossl"
if [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
then
        server="zerossl"
        backup_server="letsencrypt"
elif [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
then
        server="letsencrypt"
        backup_server="zerossl"
fi

if [ -z "${SYSTEM_FROM_EMAIL_ADDRESS}" ]
then
        SYSTEM_FROM_EMAIL_ADDRESS="${DNS_USERNAME}"
fi

if [ -z "${SYSTEM_FROM_EMAIL_ADDRESS}" ]
then
        /bin/echo "Error: Neither SYSTEM_FROM_EMAIL_ADDRESS nor DNS_USERNAME is set for ACME account registration." >&2
        exit 1
fi

acme_home="${HOME}/.acme.sh"
acme_bin="${acme_home}/acme.sh"

if [ -d "${acme_home}/${WEBSITE_URL}_ecc" ]
then
        /bin/rm -rf "${acme_home}/${WEBSITE_URL}_ecc"
fi

"${BUILD_HOME}/installation/InstallSocat.sh" "${BUILDOS}"
"${BUILD_HOME}/installation/InstallAcme.sh" "${BUILDOS}" "${SYSTEM_FROM_EMAIL_ADDRESS}"

if [ ! -x "${acme_bin}" ]
then
        /bin/echo "Error: acme.sh binary not found or not executable at ${acme_bin}" >&2
        exit 1
fi

if "${acme_bin}" --update-account -m "${SYSTEM_FROM_EMAIL_ADDRESS}" --server ${server} --home "${acme_home}"
then
        /bin/echo "Successfully updated ACME account."
else
        /bin/echo "Failed to update an existing ACME account registering a new account."
        "${acme_bin}" --register-account -m "${SYSTEM_FROM_EMAIL_ADDRESS}" --server zerossl --home "${acme_home}"
fi

"${acme_bin}" --set-default-ca --server "${server}"

staging_flag=""
if [ "${SSL_LIVE_CERT}" = "0" ]
then
        staging_flag="--staging"
fi

cleanup_cf_env()
{
        unset CF_Account_ID CF_Token CF_Key CF_Email
}
trap cleanup_cf_env EXIT INT TERM

issue_with_failover()
{
        dns_plugin="${1}"

        set +e
        "${acme_bin}" --issue --dns "${dns_plugin}" -d "${WEBSITE_URL}" --server "${server}" ${staging_flag} --standalone --force --always-force-new-domain-key
        issue_exit="$?"
        set -e

        if [ "${issue_exit}" -ne 0 ]
        then
                /bin/echo "Warning: Primary CA (${server}) failed for ${WEBSITE_URL}; retrying with backup CA (${backup_server})..." >&2
                "${acme_bin}" --issue --dns "${dns_plugin}" -d "${WEBSITE_URL}" --server "${backup_server}" ${staging_flag} --standalone --force --always-force-new-domain-key
        fi
}

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
                                account_id="$(printf '%s\n' "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $1}')"
                                api_token="$(printf '%s\n' "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
                                export CF_Account_ID="${account_id}"
                                export CF_Token="${api_token}"
                                ;;
                        *)
                                export CF_Key="${DNS_SECURITY_KEY}"
                                export CF_Email="${DNS_USERNAME}"
                                ;;
                esac

                issue_with_failover "dns_cf"
                ;;
        digitalocean)
                if [ -f "${acme_home}/dnsapi/dns_dgon.sh" ]
                then
                        /bin/cp "${BUILD_HOME}/services/security/ssl/acme/acme-overrides/digitalocean.sh" "${acme_home}/dnsapi/dns_dgon.sh"
                fi
                issue_with_failover "dns_dgon"
                ;;
        exoscale)
                if [ -f "${acme_home}/dnsapi/dns_exoscale.sh" ]
                then
                        /bin/cp "${BUILD_HOME}/services/security/ssl/acme/acme-overrides/exoscale.sh" "${acme_home}/dnsapi/dns_exoscale.sh"
                fi
                issue_with_failover "dns_exoscale"
                ;;
        linode)
                if [ -f "${acme_home}/dnsapi/dns_linode_v4.sh" ]
                then
                        /bin/cp "${BUILD_HOME}/services/security/ssl/acme/acme-overrides/linode.sh" "${acme_home}/dnsapi/dns_linode_v4.sh"
                fi
                issue_with_failover "dns_linode_v4"
                ;;
        vultr)
                if [ -f "${acme_home}/dnsapi/dns_vultr.sh" ]
                then
                        /bin/cp "${BUILD_HOME}/services/security/ssl/acme/acme-overrides/vultr.sh" "${acme_home}/dnsapi/dns_vultr.sh"
                fi
                issue_with_failover "dns_vultr"
                ;;
        *)
                /bin/echo "Error: Unsupported DNS_CHOICE '${DNS_CHOICE}'." >&2
                exit 1
                ;;
esac

cleanup_cf_env
trap - EXIT INT TERM

exit 0



