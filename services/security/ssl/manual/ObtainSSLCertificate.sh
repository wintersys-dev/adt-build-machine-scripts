
#!/bin/sh
#: Name:        ObtainSSLCertificate.sh
#: Purpose:     Allows a user to manually supply an SSL/TLS certificate chain and private key.
#:              Supports reusing an existing certificate or supplying a new certificate.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ObtainSSLCertificate.sh [website_url]
#:              ObtainSSLCertificate.sh [-h|--help]
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
#:   - /usr/bin/openssl
#:   - External binaries: cat, echo, grep, cut, mkdir, chmod, mv, rm, cmp
#:
#: Exit Codes:
#:   0          Certificate successfully accepted or manual SSL generation not required
#:   1          Missing configuration, missing dependencies, invalid certificate/key, or operation failure
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

# Retrieve build configuration variables
set +e
CLOUDHOST="$("${var_helper}" 'CLOUDHOST')"
BUILD_IDENTIFIER="$("${var_helper}" 'BUILD_IDENTIFIER')"
DNS_CHOICE="$("${var_helper}" 'DNS_CHOICE')"
SSL_GENERATION_METHOD="$("${var_helper}" 'SSL_GENERATION_METHOD')"

if [ -n "${website_url}" ]
then
        WEBSITE_URL="${website_url}"
else
        WEBSITE_URL="$("${var_helper}" 'WEBSITE_URL')"
fi
set -e

# Manual certificate entry is only required when the manual method is selected
if [ "${SSL_GENERATION_METHOD}" != "MANUAL" ]
then
        exit 0
fi

# Validate required configuration variables
if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || \
   [ -z "${DNS_CHOICE}" ] || [ -z "${WEBSITE_URL}" ]
then
        /bin/echo "Error: Missing required SSL configuration variables (CLOUDHOST, BUILD_IDENTIFIER, DNS_CHOICE, or WEBSITE_URL)." >&2
        exit 1
fi

if [ ! -x "${hardcore_helper}" ]
then
        /bin/echo "Error: IsHardcoreBuild.sh missing or not executable at ${hardcore_helper}" >&2
        exit 1
fi

if [ ! -x /usr/bin/openssl ]
then
        /bin/echo "Error: /usr/bin/openssl is missing or not executable." >&2
        exit 1
fi

# Resolve SSL certificate storage directory
ssl_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${WEBSITE_URL}"

fullchain_cert="${ssl_dir}/fullchain.pem"
private_key="${ssl_dir}/privkey.pem"

response="INPUTNEW"

# Check whether an existing certificate can be reused
if [ -f "${fullchain_cert}" ] && [ -f "${private_key}" ]
then
        status "There is a certificate I can use. Do you want me to use that, or are you going to give me a new one?"
        status "Found a certificate for this domain. For your information, this is its expiry date"

        /usr/bin/openssl x509 -in "${fullchain_cert}" -noout -enddate

        status "Please enter Y to use the existing one. Anything else to input a new one"

        if [ "$("${hardcore_helper}")" != "1" ]
        then
                if IFS= read -r response
                then
                        :
                else
                        response="INPUTNEW"
                fi
        fi
fi

# Determine whether an existing certificate should be reused
if [ "${response}" = "Y" ] || [ "${response}" = "y" ]
then
        status "Using the existing SSL certificate for ${WEBSITE_URL}"
        exit 0
fi

# Create the SSL certificate storage directory if required
if [ ! -d "${ssl_dir}" ]
then
        /bin/mkdir -p "${ssl_dir}"
fi

# Restrict permissions on newly created temporary certificate files
umask 077

tmp_fullchain="${ssl_dir}/.fullchain.pem.$$"
tmp_private_key="${ssl_dir}/.privkey.pem.$$"
tmp_cert_public="${ssl_dir}/.cert-public.pem.$$"
tmp_key_public="${ssl_dir}/.key-public.pem.$$"

cleanup()
{
        /bin/rm -f "${tmp_fullchain}" \
                  "${tmp_private_key}" \
                  "${tmp_cert_public}" \
                  "${tmp_key_public}"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

status "You have selected the manual method of generating an SSL certificate. This presumes that you have the necessary SSL files from a 3rd party."
status "Certificate provider. So, here I will have to ask you to input the certificates so that I can pass them over to your servers."
status "So, mate, please paste your certificate chain here. <ctrl d> when done"
status "ESSENTIAL - Only copy from the first dash in the file '-' to the last dash in the file. Do not copy any prefixed whitespace or suffixed whitespace"

/bin/cat > "${tmp_fullchain}"

status "Cheers. So, mate, please paste your certificate key here. <ctrl d> when done"
status "ESSENTIAL - Only copy from the first dash in the file '-' to the last dash in the file. Do not copy any prefixed whitespace or suffixed whitespace"

/bin/cat > "${tmp_private_key}"

# Validate the supplied certificate chain
status "Validating the supplied SSL certificate chain"

if ! /usr/bin/openssl x509 -in "${tmp_fullchain}" -noout
then
        status "Error: The supplied SSL certificate is invalid."
        exit 1
fi

# Validate the supplied private key
status "Validating the supplied SSL private key"

if ! /usr/bin/openssl pkey -in "${tmp_private_key}" -noout
then
        status "Error: The supplied SSL private key is invalid."
        exit 1
fi

# Extract the public key from the certificate
if ! /usr/bin/openssl x509 -in "${tmp_fullchain}" -pubkey -noout > "${tmp_cert_public}"
then
        status "Error: Unable to extract the public key from the SSL certificate."
        exit 1
fi

# Extract the public key from the private key
if ! /usr/bin/openssl pkey -in "${tmp_private_key}" -pubout > "${tmp_key_public}"
then
        status "Error: Unable to extract the public key from the SSL private key."
        exit 1
fi

# Ensure the supplied certificate and private key belong together
if ! /usr/bin/cmp -s "${tmp_cert_public}" "${tmp_key_public}"
then
        status "Error: The supplied SSL certificate and private key do not match."
        exit 1
fi

status "SSL certificate and private key successfully validated."

# Set restrictive permissions before installing the certificate files
/bin/chmod 400 "${tmp_fullchain}" "${tmp_private_key}"

# Install the validated certificate and private key
/bin/mv -f "${tmp_fullchain}" "${fullchain_cert}"
/bin/mv -f "${tmp_private_key}" "${private_key}"

status "Manual SSL certificate successfully installed for ${WEBSITE_URL}"

exit 0


