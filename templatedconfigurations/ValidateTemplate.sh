#!/bin/sh
###################################################################################
# Description : This will validate our template against the quick spec definitions.
# These are just rudimentary checks and it can't be 100% guaranteed that there is nothing
# misconfigured in the template if these checks pass, but, we can be more confident that
# the template is correctly configured.
# Author: Peter Winter
# Date  : 23/11/2026
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
#set -x

status () {
	status_set="1"
	"${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" "yellow"
}

status1 () {
	"${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

status2 () {
	"${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" "blue"
}

echo () {
	yellow="`/bin/echo -e '\033[33m'`"
	reset="`/bin/echo -e '\033[0m'`"
	/bin/echo "${yellow} ${1} ${reset}"
}

load_template_safely () {
	tpl="${1}"
	line_num=0

	case "${key}" in
	PATH|HOME|BUILD_HOME|IFS|LD_PRELOAD|LD_LIBRARY_PATH)
		${log_command} "Security error on line ${line_num}: template cannot override protected variable '${key}'"
		exit 1
		;;
	esac


	while IFS= read -r line || [ -n "${line}" ]
	do
		line_num=$((line_num + 1))

		# Strip leading whitespace
		trimmed="$(/usr/bin/printf '%s' "${line}" | /bin/sed 's/^[[:space:]]*//')"

		# Skip empty lines and comments
		case "${trimmed}" in
			""|\#*) continue ;;
		esac

		# Strip optional leading 'export '
		trimmed="${trimmed#export }"

		# Ensure line is a valid KEY=VALUE assignment
		case "${trimmed}" in
			[A-Za-z_]*=*)
				key="${trimmed%%=*}"
				raw_val="${trimmed#*=}"
				;;
			*)
				${log_command} "Security/Syntax error on line ${line_num} of ${tpl}: invalid assignment '${trimmed}'"
				exit 1
				;;
		esac

		# Validate variable name strictly
		if ! /usr/bin/printf '%s\n' "${key}" | /bin/grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
		then
			${log_command} "Invalid variable name '${key}' on line ${line_num} of ${tpl}"
			exit 1
		fi

		# Prevent template from hijacking critical system or toolkit environment variables
		case "${key}" in
			PATH|HOME|BUILD_HOME|IFS|LD_PRELOAD|LD_LIBRARY_PATH)
				${log_command} "Security error on line ${line_num}: template cannot override protected variable '${key}'"
				exit 1
				;;
		esac

		# Reject command substitution $(...) or backticks unless wrapped in single quotes
		case "${raw_val}" in
			\'*\')
				# Single-quoted literal: strip outer single quotes safely
				val="${raw_val#\'}"
				val="${val%\'}"
				case "${val}" in
					*\'*)
						${log_command} "Unsafe unescaped single quote on line ${line_num} of ${tpl}"
						exit 1
						;;
				esac
				;;
			*)
				# Reject $(...), backticks, or unquoted command separators (; | & > <)
				if /usr/bin/printf '%s\n' "${raw_val}" | /bin/grep -Eq '(\$\(|`)'
				then
					${log_command} "Security error on line ${line_num} of ${tpl}: command substitution is forbidden in templates"
					exit 1
				fi

				case "${raw_val}" in
					\"*\")
						val="${raw_val#\"}"
						val="${val%\"}"
						;;
					*)
						if /usr/bin/printf '%s\n' "${raw_val}" | /bin/grep -Eq '[;|&><[:space:]]'
						then
							${log_command} "Syntax/Security error on line ${line_num} of ${tpl}: unquoted special characters or spaces"
							exit 1
						fi
						val="${raw_val}"
						;;
				esac
				;;
		esac

		# Assign safely without interpreting metacharacters
		eval "${key}=\${val}"
		export "${key}"
	done < "${tpl}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
quick_specification="${BUILD_HOME}/specifications/quick_specification.dat"
status_set="0"

status1 2>/dev/null

if [ "$?" = "0" ]
then
	log_command="status "
	log_command1="status1 "
else
	/bin/echo ""
	log_command="echo "
	log_command1="/bin/echo "
fi

log_command2="status2 "

templatefile="${1:-}"
if [ -n "${templatefile}" ]
then
	if [ ! -r "${templatefile}" ]
	then
		${log_command} "Template file (${templatefile}) does not exist or is not readable"
		exit 1
	fi

	if /bin/grep -q "$(/usr/bin/printf '\r')" "${templatefile}"
	then
		${log_command} "Template file (${templatefile}) contains Windows CRLF (\\r) line endings; convert it with dos2unix first"
		exit 1
	fi

	if ! /bin/sh -n "${templatefile}" 2>/dev/null
	then
		${log_command} "Template file (${templatefile}) has a shell syntax error (check unclosed quotes or special characters)"
		exit 1
	fi

	load_template_safely "${templatefile}"
fi
# Helper: validate a variable against quick_specification.dat (rejects empty values)
check_spec () {
	var_name="${1}"
	var_value="${2}"
	extra_filter="${3:-}"

	if [ -z "${var_value}" ]
	then
		${log_command} "Your value for the variable ${var_name} is empty please review"
		return 1
	fi

	if [ -n "${extra_filter}" ]
	then
		spec_match="$(/bin/grep "^${var_name} " "${quick_specification}" 2>/dev/null | /bin/grep -w -- "${var_value}" | /bin/grep -w -- "${extra_filter}")"
	else
		spec_match="$(/bin/grep "^${var_name} " "${quick_specification}" 2>/dev/null | /bin/grep -w -- "${var_value}")"
	fi

	if [ -z "${spec_match}" ]
	then
		${log_command} "Your value for the variable ${var_name} (${var_value}) doesn't appear to be valid please review"
		return 1
	fi
	return 0
}

# Helper: validate email address syntax (supports dots, hyphens, underscores, plus signs, and subdomains)
check_email () {
	var_name="${1}"
	var_value="${2}"

	if [ -z "${var_value}" ] || ! /usr/bin/printf '%s\n' "${var_value}" | /bin/grep -Eq '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
	then
		${log_command} "It looks to me like the email address for the variable ${var_name} (${var_value}) doesn't appear to be valid please review"
		return 1
	fi
	return 0
}

${log_command1} ""
status "ATTENTION" "figlet"
${log_command1} ""

${log_command1} "######################################################################################################################################################################"
${log_command1} "If you see any warning messages below its because I believe that you might want to double check some values in your template in some way before you make a deployment"
${log_command1} "You may get some soft warnings if you check them out and find them to be soft you can safely continue whilst ignoring them"
${log_command1} "Your currently active template is : ${templatefile}"
${log_command1} "######################################################################################################################################################################"
${log_command1} ""
${log_command1} "####################TEMPLATE VALIDATION REPORT BEGINNING####################"
check_spec "BUILDOS" "${BUILDOS}"

if check_spec "BUILDOS_VERSION" "${BUILDOS_VERSION}"
then
	if [ "${BUILDOS}" = "ubuntu" ] && [ "${BUILDOS_VERSION}" != "24.04" ]
	then
		${log_command} "Your value for the variable BUILDOS_VERSION (${BUILDOS_VERSION}) doesn't appear to be valid for ubuntu please review"
	elif [ "${BUILDOS}" = "debian" ] && [ "${BUILDOS_VERSION}" != "12" ] && [ "${BUILDOS_VERSION}" != "13" ]
	then
		${log_command} "Your value for the variable BUILDOS_VERSION (${BUILDOS_VERSION}) doesn't appear to be valid for debian please review"
	fi
fi

check_spec "APPLICATION" "${APPLICATION}"

for host_base in `/bin/echo "${S3_HOST_BASE}" | /bin/sed 's/:/ /g'`
do
	check_spec "S3_HOST_BASE" "${host_base}"
done

S3_ACCESS_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_ACCESS_KEY`"
no_tokens1="`/usr/bin/printf '%s' "${S3_ACCESS_KEY}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l`"
no_tokens1="`/usr/bin/expr "${no_tokens1}" + 1`"

S3_SECRET_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_SECRET_KEY`"
no_tokens2="`/usr/bin/printf '%s' "${S3_SECRET_KEY}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l`"
no_tokens2="`/usr/bin/expr "${no_tokens2}" + 1`"

S3_LOCATION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_LOCATION`"
no_tokens3="`/usr/bin/printf '%s' "${S3_LOCATION}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l`"
no_tokens3="`/usr/bin/expr "${no_tokens3}" + 1`"

S3_HOST_BASE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_HOST_BASE`"
no_tokens4="`/usr/bin/printf '%s' "${S3_HOST_BASE}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l`"
no_tokens4="`/usr/bin/expr "${no_tokens4}" + 1`"

if [ "${no_tokens1}" != "${no_tokens2}" ] || [ "${no_tokens2}" != "${no_tokens3}" ] || [ "${no_tokens3}" != "${no_tokens4}" ]
then
	${log_command} "There seems to be an inconsistent number of values for your datastore parameters"
	${log_command} "S3_ACCESS_KEY ( ${no_tokens1} values configured ) S3_SECRET_KEY ( ${no_tokens2} values configured )"
	${log_command} "S3_LOCATION ( ${no_tokens3} values configured )  S3_HOST_BASE ( ${no_tokens4} values configured )"
fi

if [ -n "${S3_LOCATION}" ]
then
	for s3_loc in `/bin/echo "${S3_LOCATION}" | /bin/sed 's/|/ /g'`
	do
		check_spec "S3_LOCATION" "${s3_loc}"
	done
fi

check_spec "EMAIL_NOTIFICATION_LEVEL" "${EMAIL_NOTIFICATION_LEVEL}"
check_spec "DNS_CHOICE" "${DNS_CHOICE}"

if [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && ( [ "${BUILD_ARCHIVE_CHOICE}" = "virgin" ] || [ "${BUILD_ARCHIVE_CHOICE}" = "baseline" ] )
then
	${log_command} "Your BUILD_ARCHIVE_CHOICE is set to ${BUILD_ARCHIVE_CHOICE} and that can't be when you are deploying from snapshots"
	${log_command} "You have to deploy from a temporal backup if you are building your servers based on snapshots"
fi

check_spec "APPLICATION_REPOSITORY_PROVIDER" "${APPLICATION_REPOSITORY_PROVIDER}"
check_spec "BUILD_MACHINE_VPC" "${BUILD_MACHINE_VPC}"
check_spec "SYSTEM_EMAIL_PROVIDER" "${SYSTEM_EMAIL_PROVIDER}"
check_spec "DEPLOYMENT_MODE" "${DEPLOYMENT_MODE}"
check_spec "LOADBALANCER" "${LOADBALANCER}"

if [ "${NO_AUTHENTICATORS}" != "0" ] && ( [ -z "${SYSTEM_EMAIL_PROVIDER}" ] || [ -z "${SYSTEM_TO_EMAIL_ADDRESS}" ] || [ -z "${SYSTEM_FROM_EMAIL_ADDRESS}" ] || [ -z "${SYSTEM_EMAIL_USERNAME}" ] || [ -z "${SYSTEM_EMAIL_PASSWORD}" ] )
then
	${log_command} "You are deploying an authentication server and so SMTP must be fully setup and it looks like it isn't"
fi

if [ "${NO_AUTHENTICATORS}" != "0" ] && ( [ -z "${AUTH_SERVER_URL}" ] || [ -z "${AUTH_DNS_USERNAME}" ] || [ -z "${AUTH_DNS_SECURITY_KEY}" ] || [ -z "${USER_EMAIL_DOMAIN}" ] )
then
	${log_command} "You are deploying an authentication server and it looks like its DNS system might not be set up"
fi

if [ "${NO_AUTHENTICATORS}" != "0" ]
then
	check_spec "AUTH_DNS_CHOICE" "${AUTH_DNS_CHOICE}"
fi

if [ "${NO_AUTHENTICATORS}" != "0" ] && [ "${DNS_CHOICE}" = "cloudflare" ]
then
	${log_command} "You are deploying an authentication server and it looks like your main DNS provider is set to cloudflare which it shouldn't be"
fi

if [ "${DNS_CHOICE}" = "cloudflare" ] && [ -z "`/usr/bin/printf '%s' "${DNS_SECURITY_KEY}" | /bin/grep ':::'`" ]
then
	${log_command} "Your value for DNS_SECURITY_KEY seems to be malformed"
fi

check_spec "WEBSERVER_CHOICE" "${WEBSERVER_CHOICE}"
check_spec "REVERSE_PROXY_WEBSERVER" "${REVERSE_PROXY_WEBSERVER}"
check_spec "DATABASE_INSTALLATION_TYPE" "${DATABASE_INSTALLATION_TYPE}"
check_spec "PERSIST_ASSETS_TO_DATASTORE" "${PERSIST_ASSETS_TO_DATASTORE}"

if [ "${PERSIST_ASSETS_TO_DATASTORE}" = "2" ] && [ "${NO_REVERSE_PROXIES}" = "0" ]
then
	${log_command} "It's pointless to set PERSIST_ASSETS_TO_DATASTORE to 2 without deploying any reverse proxy machines"
fi

if [ -d "${BUILD_HOME}/runtime/${CLOUDHOST}" ]
then
	existing_build_identifiers="`/bin/ls "${BUILD_HOME}/runtime/${CLOUDHOST}"`"
	if [ -n "${BUILD_IDENTIFIER}" ] && [ -z "`/bin/echo "${existing_build_identifiers}" | /bin/grep -w -- "${BUILD_IDENTIFIER}"`" ] && [ -n "`/bin/echo "${existing_build_identifiers}" | /bin/grep -F -- "${BUILD_IDENTIFIER}"`" ]
	then
		${log_command} "Your BUILD_IDENTIFIER (${BUILD_IDENTIFIER}) seems to be a substring of an existing BUILD_IDENTIFIER this is NOT recommended"
		${log_command} "For example, if you have BUILD_IDENTIFIERS such as '1test' or 'test2' then 'test' is not a valid BUILD_IDENTIFIER"
	fi
fi

valid_build_id="`/usr/bin/printf '%s' "${BUILD_IDENTIFIER}" | /bin/grep -E '^[a-zA-Z0-9-]+$' | /bin/grep -v -- '-$'`"
build_identifier_length="`/usr/bin/printf '%s' "${valid_build_id}" | /usr/bin/wc -c | /usr/bin/tr -d ' '`"

if [ "${build_identifier_length}" = "0" ]
then
	${log_command} "It looks like your build identifier (${BUILD_IDENTIFIER}) is not valid"
elif [ "${build_identifier_length}" -gt "12" ]
then
	${log_command} "It looks like your build identifier (${BUILD_IDENTIFIER}) is more than 12 characters"
fi

if [ -z "${VPC_IP_RANGE}" ]
then
	${log_command} "Your value for the variable VPC_IP_RANGE seems not to be set this is a MANDATORY SETTING"
fi
check_spec "BUILD_ARCHIVE_CHOICE" "${BUILD_ARCHIVE_CHOICE}"
check_spec "APPLICATION_LANGUAGE" "${APPLICATION_LANGUAGE}"

if ! check_spec "IN_PARALLEL" "${IN_PARALLEL}"
then
	export IN_PARALLEL="0"
fi

if [ "`/bin/grep -E '(^AUTHENTICATORPORTS:.*|^REVERSEPROXYPORTS:.*|^AUTOSCALERPORTS:.*|^WEBSERVERPORTS:.*|^DATABASEPORTS:.*)' "${BUILD_HOME}/configuration/firewall.dat" | /usr/bin/wc -l | /usr/bin/tr -d ' '`" != "5" ]
then
	${log_command} "I was expecting 5 firewall config settings is your ${BUILD_HOME}/configuration/firewall.dat set correctly?"
fi

AUTHENTICATOR_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTHENTICATOR_TYPE`"

if [ "${AUTHENTICATOR_TYPE}" = "firewall" ]
then
	if [ -n "`/bin/grep '^REVERSEPROXYPORTS:' "${BUILD_HOME}/configuration/firewall.dat" | /bin/grep -w 443`" ]
	then
		${log_command} "Are you sure that your firewall is configured correctly in ${BUILD_HOME}/configuration/firewall.dat"
	fi
fi

if [ "${AUTHENTICATOR_TYPE}" = "basic-auth" ] || [ "${AUTHENTICATOR_TYPE}" = "whitelist" ]
then
	if [ -z "`/bin/grep '^REVERSEPROXYPORTS:' "${BUILD_HOME}/configuration/firewall.dat" | /bin/grep -w 443`" ]
	then
		${log_command} "Are you sure that your firewall is configured correctly in ${BUILD_HOME}/configuration/firewall.dat"
	fi
fi

SSH_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT`"
if [ -n "${SSH_PORT}" ]
then
	wireguard_port="`/usr/bin/expr "${SSH_PORT}" + 1`"
fi

if [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ]
then
	if [ -n "`/bin/grep '^REVERSEPROXYPORTS:' "${BUILD_HOME}/configuration/firewall.dat" | /bin/grep -w 443`" ]
	then
		${log_command} "Detected that wireguard authenticator type has been set"
		${log_command} "Are you sure that your firewall is configured correctly in ${BUILD_HOME}/configuration/firewall.dat"
		${log_command} "The whole point of the wireguard authenticator type is to keep port 443 closed"
	fi
fi

if ! /usr/bin/printf '%s\n' "${MAX_WEBSERVERS}" | /bin/grep -Eq '^[0-9]+$'
then
	${log_command} "Your value for the variable MAX_WEBSERVERS (${MAX_WEBSERVERS}) doesn't appear to be valid please review"
fi

check_spec "SYNC_WEBROOTS" "${SYNC_WEBROOTS}"
check_spec "NO_AUTOSCALERS" "${NO_AUTOSCALERS}"
check_spec "NO_WEBSERVERS" "${NO_WEBSERVERS}"
check_spec "NO_REVERSE_PROXIES" "${NO_REVERSE_PROXIES}"

if [ "${NO_REVERSE_PROXIES}" != "0" ]
then
	check_spec "REVERSE_PROXY_WEBSERVER" "${REVERSE_PROXY_WEBSERVER}"
fi

if [ "${MOD_SECURITY}" = "1" ] && [ "${WEBSERVER_CHOICE}" = "NGINX" ] && [ -z "`/bin/grep '^NGINX:source' "${BUILD_HOME}/configuration/software.dat"`" ]
then
	${log_command} "To use NGINX with modsecurity enabled NGINX needs to be compiled from source which you can configure in ${BUILD_HOME}/configuration/software.dat"
fi

if [ "${MOD_SECURITY}" = "1" ] && [ "${WEBSERVER_CHOICE}" = "LIGHTTPD" ]
then
	${log_command} "Mod security isn't available for use with the LIGHTTPD webserver"
fi

if [ "${DEVELOPMENT}" = "1" ] && [ "${NO_AUTOSCALERS}" != "0" ]
then
	${log_command} "You are in development mode, NO_AUTOSCALERS should be 0 not (${NO_AUTOSCALERS}) and so doesn't appear to be valid please review"
	"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "NO_AUTOSCALERS=0"
fi

if [ "${DEPLOYMENT_MODE}" = "PRODUCTION" ] && [ "${NO_AUTOSCALERS}" = "0" ]
then
	${log_command} "You are in production mode, NO_AUTOSCALERS should not be 0 and so doesn't appear to be valid please review"
fi

if [ "${DEPLOYMENT_MODE}" = "DEVELOPMENT" ] && [ "${NO_WEBSERVERS}" != "1" ]
then
	${log_command} "In development mode, the number of webservers has to be 1"
	"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "NO_WEBSERVERS=1"
fi

check_spec "PHP_VERSION" "${PHP_VERSION}"

cloudhost="`/usr/bin/printf '%s' "${CLOUDHOST}" | /usr/bin/tr '[:lower:]' '[:upper:]'`"

if [ -z "${REGION}" ] || [ -z "`/bin/grep '^REGION ' "${quick_specification}" | /bin/grep -w -- "${REGION}" 2>/dev/null`" ]
then
	if [ "${cloudhost}" = "EXOSCALE" ]
	then
		if [ -z "${REGION}" ] || [ -z "`/bin/grep '^REGION ' "${quick_specification}" | /bin/grep -w -- "${REGION}" | /bin/grep -w -- "${cloudhost}" 2>/dev/null`" ]
		then
			${log_command} "Your value for the variable REGION (${REGION}) doesn't appear to be valid please review"
		fi
	fi
fi

if [ "${MULTI_REGION}" = "0" ] || ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
	if [ "${CLOUDHOST}" = "digitalocean" ] && [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ] && [ "${DB_PORT}" != "25060" ]
	then
		${log_command} "Your value for the variable DB_PORT is ${DB_PORT} and it can only be '25060' in this configuration"
	fi
fi

for server_var in DB_SERVER_TYPE AS_SERVER_TYPE WS_SERVER_TYPE
do
	eval "server_val=\"\${${server_var}}\""
	if [ -z "${server_val}" ] || [ -z "`/bin/grep "^${server_var} " "${quick_specification}" | /bin/grep -w -- "${server_val}" 2>/dev/null`" ]
	then
		if [ -z "${server_val}" ] || [ -z "`/bin/grep "^${server_var} " "${quick_specification}" | /bin/grep -w -- "${server_val}" | /bin/grep -w -- "${cloudhost}" 2>/dev/null`" ]
		then
			${log_command} "Your value for the variable ${server_var} (${server_val}) doesn't appear to be valid please review"
		fi
	fi
done

check_spec "MACHINE_TYPE" "${MACHINE_TYPE}"
check_spec "ALGORITHM" "${ALGORITHM}"
check_spec "INFRASTRUCTURE_REPOSITORY_PROVIDER" "${INFRASTRUCTURE_REPOSITORY_PROVIDER}"
check_spec "DB_INSTALL_MODE" "${DB_INSTALL_MODE}"
check_spec "SSL_GENERATION_METHOD" "${SSL_GENERATION_METHOD}"
check_spec "SSL_GENERATION_SERVICE" "${SSL_GENERATION_SERVICE}"
check_spec "SSL_LIVE_CERT" "${SSL_LIVE_CERT}"

if [ "${NO_AUTHENTICATORS}" != "0" ]
then
	check_spec "AUTHENTICATOR_TYPE" "${AUTHENTICATOR_TYPE}"
fi

if [ -n "`/bin/grep '^SSLCERTCLIENT:lego' "${BUILD_HOME}/configuration/software.dat"`" ] && [ "${SSL_GENERATION_SERVICE}" != "LETSENCRYPT" ]
then
	${log_command} "There seems to be a mismatch between your SSL CLIENT software choice in ${BUILD_HOME}/configuration/software.dat"
	${log_command} "and your chosen ssl generation service (${SSL_GENERATION_SERVICE})"
	${log_command} "The 'lego' SSL CLIENT can only be used with the LETSENCRYPT certificate service"
fi

if [ -n "`/bin/grep '^SSLCERTCLIENT:acme' "${BUILD_HOME}/configuration/software.dat"`" ] && [ "${SSL_GENERATION_SERVICE}" != "ZEROSSL" ]
then
	${log_command} "There seems to be a mismatch between your SSL CLIENT software choice in ${BUILD_HOME}/configuration/software.dat"
	${log_command} "and your chosen ssl generation service (${SSL_GENERATION_SERVICE})"
	${log_command} "The 'acme' SSL CLIENT can only be used with the ZEROSSL certificate service"
fi

check_spec "ACTIVE_FIREWALLS" "${ACTIVE_FIREWALLS}"
case "${APPLICATION}" in
	joomla|wordpress|drupal|moodle)
		if [ -z "${PHP_VERSION}" ] || [ -z "`/bin/echo "8.1 8.2 8.3 8.4" | /bin/grep -w -- "${PHP_VERSION}"`" ]
		then
			${log_command} "I am suspicious that the version of PHP you are installing (${PHP_VERSION}) isn't compatible with ${APPLICATION}"
		fi
		;;
esac

check_email "DNS_USERNAME" "${DNS_USERNAME}"
check_email "SYSTEM_TO_EMAIL_ADDRESS" "${SYSTEM_TO_EMAIL_ADDRESS}"
check_email "SYSTEM_FROM_EMAIL_ADDRESS" "${SYSTEM_FROM_EMAIL_ADDRESS}"
check_email "GIT_EMAIL_ADDRESS" "${GIT_EMAIL_ADDRESS}"

if [ -z "`/usr/bin/printf '%s\n' "${WEBSITE_URL}" | /bin/grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'`" ]
then
	${log_command} "It looks to me like the value for the variable WEBSITE_URL (${WEBSITE_URL}) doesn't appear to be valid please review"
fi

if [ -z "${WEBSITE_NAME}" ] || [ -z "`/usr/bin/printf '%s\n' "${WEBSITE_URL}" | /bin/grep -Fw -- "${WEBSITE_NAME}"`" ]
then
	${log_command} "It looks to me like the value for the variable WEBSITE_NAME (${WEBSITE_NAME}) doesn't appear to match WEBSITE_URL (${WEBSITE_URL}) please review"
fi

if [ -z "${SERVER_TIMEZONE_CONTINENT}" ] || [ ! -d "/usr/share/zoneinfo/${SERVER_TIMEZONE_CONTINENT}" ]
then
	${log_command} "It looks like your variable SERVER_TIMEZONE_CONTINENT (${SERVER_TIMEZONE_CONTINENT}) doesn't appear to be valid please review"
else
	if [ -z "${SERVER_TIMEZONE_CITY}" ] || [ ! -e "/usr/share/zoneinfo/${SERVER_TIMEZONE_CONTINENT}/${SERVER_TIMEZONE_CITY}" ]
	then
		${log_command} "It looks like your variable SERVER_TIMEZONE_CITY (${SERVER_TIMEZONE_CITY}) doesn't appear to be valid for ${SERVER_TIMEZONE_CONTINENT} please review"
	fi
fi

if [ "${BUILD_ARCHIVE_CHOICE}" = "baseline" ]
then
	if [ -z "`"${BUILD_HOME}/services/git/ListRepository.sh" "${APPLICATION_REPOSITORY_PROVIDER}" "${APPLICATION_REPOSITORY_USERNAME}" "${APPLICATION_REPOSITORY_OWNER}" "${BASELINE_DB_REPOSITORY}" "${APPLICATION_REPOSITORY_TOKEN}"`" ]
	then
		${log_command} "I believe that the repository you have set for variable BASELINE_DB_REPOSITORY (${BASELINE_DB_REPOSITORY}) doesn't appear to be valid please review"
	fi
	if [ -z "`"${BUILD_HOME}/services/git/ListRepository.sh" "${APPLICATION_REPOSITORY_PROVIDER}" "${APPLICATION_REPOSITORY_USERNAME}" "${APPLICATION_REPOSITORY_OWNER}" "${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}" "${APPLICATION_REPOSITORY_TOKEN}"`" ]
	then
		${log_command} "I believe that the repository you have set for variable APPLICATION_BASELINE_SOURCECODE_REPOSITORY (${APPLICATION_BASELINE_SOURCECODE_REPOSITORY}) doesn't appear to be valid please review"
	fi
fi

if [ "${NO_AUTHENTICATORS}" != "0" ] && [ "${NO_REVERSE_PROXIES}" = "0" ]
then
	${log_command} "It's pointless to be deploying ${NO_AUTHENTICATORS} authenticator machine(s) without reverse proxies running because the reverse proxies action the authentication"
fi

if ( [ "${CLOUDHOST}" = "linode" ] || [ "${CLOUDHOST}" = "exoscale" ] ) && [ -z "${CLOUDHOST_ACCOUNT_ID}" ]
then
	${log_command} "It looks like CLOUDHOST_ACCOUNT_ID is blank this should definitely not be the case for ${CLOUDHOST}"
fi

if [ "${DATABASE_INSTALLATION_TYPE}" = "Postgres" ] && [ -z "`/bin/grep '^PHP' "${BUILD_HOME}/configuration/software.dat" | /bin/grep -w pgsql`" ]
then
	${log_command} "It looks like you are trying to install Postgres without PHP support for postgres (pgsql)"
fi

if ( [ "${DATABASE_INSTALLATION_TYPE}" = "Maria" ] || [ "${DATABASE_INSTALLATION_TYPE}" = "MySQL" ] ) && [ -z "`/bin/grep '^PHP' "${BUILD_HOME}/configuration/software.dat" | /bin/grep -w mysqli`" ]
then
	${log_command} "It looks like you are trying to install ${DATABASE_INSTALLATION_TYPE} without PHP support for mysql (mysqli)"
fi

if [ -n "`/usr/bin/printf '%s' "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /bin/grep -w MySQL`" ] && [ -z "`/bin/grep '^PHP' "${BUILD_HOME}/configuration/software.dat" | /bin/grep -w mysqli`" ]
then
	${log_command} "It looks like you are trying to install MySQL DBaaS without PHP support for mysql (mysqli)"
fi

if [ -n "`/usr/bin/printf '%s' "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /bin/grep -w Postgres`" ] && [ -z "`/bin/grep '^PHP' "${BUILD_HOME}/configuration/software.dat" | /bin/grep -w pgsql`" ]
then
	${log_command} "It looks like you are trying to install Postgres DBaaS without PHP support for postgres (pgsql)"
fi

check_spec "MULTI_REGION" "${MULTI_REGION}"
check_spec "PRIMARY_REGION" "${PRIMARY_REGION}"

if [ "${MULTI_REGION}" = "1" ] && [ "${NO_REVERSE_PROXIES}" = "0" ]
then
	${log_command} "You are set to deploy to multiple regions which means that you have to use reverse proxy machines"
	${log_command} "Currently your number of reverse proxy machines is set to zero"
fi

if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ] && [ -z "${DBaaS_PUBLIC_ENDPOINT}" ]
then
	${log_command} "You are configured for multi region deployment and this is not the primary region"
	${log_command} "When this is the case you have to have a DBaaS public endpoint set"
	${log_command} "Currently your DBaaS_PUBLIC_ENDPOINT is set to ''"
fi

if [ "${MULTI_REGION}" = "1" ] && [ "${DATABASE_INSTALLATION_TYPE}" != "DBaaS" ]
then
	${log_command} "You are making a multi region deployment and your database installation type is not DBaaS"
	${log_command} "This is not allowed, please correct"
fi

if [ "${ACTIVE_FIREWALLS}" = "0" ] || [ "${ACTIVE_FIREWALLS}" = "1" ]
then
	${log_command} "It is highly advised that you have a native firewall active because you may experience connection issues to your webproperty across the Internet otherwise"
	${log_command} "Currently, your value for ACTIVE_FIREWALLS is set to ${ACTIVE_FIREWALLS}"
	${log_command} "It needs to be set to 2 or 3"
fi

if [ "${MULTI_REGION}" = "1" ] && [ "${BUILD_FROM_SNAPSHOT}" = "1" ]
then
	${log_command} "Please be aware that you are in multi-region mode and you are also building from snapshots this could complicate things"
	${log_command} "And is therefore not recommended. Rather, it is preferred to just perform regular builds when in multi-region mode"
	${log_command} "That said, if you are adventurous you could give it a go"
fi

if [ "${MULTI_REGION}" = "1" ] && ( [ "${BUILD_ARCHIVE_CHOICE}" = "virgin" ] || [ "${BUILD_ARCHIVE_CHOICE}" = "baseline" ] )
then
	${log_command} "Your BUILD_ARCHIVE_CHOICE is set to ${BUILD_ARCHIVE_CHOICE} and that can't be when you are deploying for multiple regions"
	${log_command} "You have to deploy from a temporal backup if you are building your servers for multiple regions"
fi

if [ "${DB_INSTALL_MODE}" = "1" ] && [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ]
then
	${log_command} "Your DB_INSTALL_MODE setting is set to 1 you almost certainly want it to be set to 0 or 2 when you are in multi region mode and are not deploying a primary region"
fi

if [ "${status_set}" = "0" ]
then
	${log_command2} "YOUR TEMPLATE LOOKS TO BE FULLY VALIDATED"
fi

${log_command1} ""
${log_command1} "####################TEMPLATE VALIDATION REPORT ENDING####################"

${log_command1} "Press <enter> when you have reviewed and accepted any messages that have appeared above (if there are none then you are all set already and just press enter)"

if [ "`"${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh"`" != "1" ]
then
	read x
fi
