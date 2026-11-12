#!/bin/sh
########################################################################################
# @file        ConfigureNativeFirewall.sh
# @brief       Orchestrates platform-specific native firewall generation and configuration.
# @author      Peter Winter
# @date        06/11/2026
# @version     1.0
#
# @details     This script acts as a high-level wrapper that reads multi-tier architecture profiles 
#              (Authenticators, Autoscalers, Reverse Proxies, Web Servers, Databases) to determine proper 
#              network isolation rules. It constructs a complex JSON ruleset dynamically—injecting target 
#              VPC IP ranges, secure ports, build machine overrides, and custom whitelists—and hands execution 
#              off to the native script corresponding to the active cloud provider infrastructure.
#
# @param       $1  [Required] The architectural role name (e.g., adt-authenticator, adt-webserver) used 
#                             to evaluate specific conditional rulesets.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         ACTIVE_FIREWALLS    A comma or space-separated list of globally active firewall definitions.
# @env         CLOUDHOST           The infrastructure provider context identifier (e.g., linode, aws).
# @env         BUILD_IDENTIFIER    A unique build execution identifier used for resource segregation.
# @env         BUILD_MACHINE_VPC   A configuration flag ('0' or '1') declaring if the build machine resides inside the target VPC.
# @env         SSH_PORT            The custom TCP port configured for administrative secure shell access.
# @env         DB_PORT             The target application-tier network port deployed for database instances.
# @env         VPC_IP_RANGE        The standard internal private subnet CIDR block allocated to the deployment VPC.
# @env         NO_REVERSE_PROXIES  A boolean setting determining whether direct SSL rules bypass traditional reverse proxies.
# @env         REGION              The physical cloud provider data centre location where infrastructure is provisioned.
# @env         AUTHENTICATOR_TYPE  The identity verification backend protocol chosen for instance peering (e.g., wire-guard).
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - GetBuildMachineIP.sh network resolution utility.
#              - GetProxyDNSIPs.sh DNS proxy tracking service.
#              - external dependencies: awk, grep, sed, ipcalc, expr, cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Eliminates unsafe wrapper subshell nesting expressions and brackets.
#              - Validates external data via localized inputs and ensures error handling boundaries.
#
# @exit        0  Success: The platform ruleset was computed and successfully dispatched.
# @exit        1  Failure: Missing arguments, structural configuration files unreadable, or downstream execution fails.
########################################################################################
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
########################################################################################
########################################################################################
#set -x
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

linode_firewall_rules()
{
        f_name="${1}"
        f_ports="${2}"
        f_rules=""
        for firewall_port_token in ${f_ports}
        do
                if [ "$( /bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $2}' )" = "ipv4" ]
                then
                        port="$( /bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $1}' )"
                        ip_address="$( /bin/echo "${firewall_port_token}" | /usr/bin/awk -F'|' '{print $4}' )"

                        if [ -z "$( /usr/bin/ipcalc "${ip_address}" 2>/dev/null | /bin/grep "INVALID" )" ]
                        then
                                f_rules="${f_rules}"'{"addresses":{"ipv4":["'${ip_address}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${port}'"},{"addresses":{"ipv4":["'${ip_address}'"]},"action":"ACCEPT","protocol":"UDP","ports":"'${port}'"}'
                        fi
                fi
        done
        /bin/echo "${f_rules}"
}

# Input validation
if [ -z "${1}" ]
then
        status "Error: 1 argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

# Secure framework configuration value extraction
ACTIVE_FIREWALLS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" ACTIVE_FIREWALLS)"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
BUILD_MACHINE_VPC="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_MACHINE_VPC)"
SSH_PORT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSH_PORT)"
DB_PORT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DB_PORT)"
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
NO_REVERSE_PROXIES="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" NO_REVERSE_PROXIES)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"
AUTHENTICATOR_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTHENTICATOR_TYPE)"
build_machine_ip="$("${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh")"

authenticator_firewall_ports=""
autoscaler_firewall_ports=""
reverseproxy_firewall_ports=""
webserver_firewall_ports=""
database_firewall_ports=""

firewall_dat="${BUILD_HOME}/configuration/firewall.dat"
if [ -f "${firewall_dat}" ]
then
        authenticator_firewall_ports="$(/bin/grep "^AUTHENTICATORPORTS" "${firewall_dat}" | /usr/bin/awk -F':' '{print $2}')"
        autoscaler_firewall_ports="$(/bin/grep "^AUTOSCALERPORTS" "${firewall_dat}" | /usr/bin/awk -F':' '{print $2}')"
        reverseproxy_firewall_ports="$(/bin/grep "^REVERSEPROXYPORTS" "${firewall_dat}" | /usr/bin/awk -F':' '{print $2}')"
        webserver_firewall_ports="$(/bin/grep "^WEBSERVERPORTS" "${firewall_dat}" | /usr/bin/awk -F':' '{print $2}')"
        database_firewall_ports="$(/bin/grep "^DATABASEPORTS" "${firewall_dat}" | /usr/bin/awk -F':' '{print $2}')"
fi

if [ "${firewall_name}" = "adt-authenticator" ]
then
        all_dns_proxy_ips="$("${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh" "yes")"
else
        all_dns_proxy_ips="$("${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh" "no")"
fi

firewall_rules=""
rule_vpc_ssh=""
rule_vpc_db=""
rule_vpc_ssl=""
rule_ssl=""
rule_wireguard=""
rule_build_machine=""
rule_build_machine_ssl=""
rule_icmp=""

if [ -n "$( /bin/echo "${firewall_name}" | /bin/grep "adt-authenticator" )" ]
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${authenticator_firewall_ports}")"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        if [ -f "${firewall_dat}" ] && [ -n "$(/bin/grep "^AUTHENTICATORPORTS:" "${firewall_dat}" | /bin/grep cloudflare)" ] && [ -n "${all_dns_proxy_ips}" ]
        then
                rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
        fi

        if [ "${BUILD_MACHINE_VPC}" = "0" ]
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

if [ -n "$( /bin/echo "${firewall_name}" | /bin/grep "adt-autoscaler" )" ]
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${autoscaler_firewall_ports}")"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
        
        if [ "${BUILD_MACHINE_VPC}" = "0" ]
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

if [ -n "$( /bin/echo "${firewall_name}" | /bin/grep "adt-reverseproxy" )" ]
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${reverseproxy_firewall_ports}")"

        if [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ]
        then
                secure_port="$(/usr/bin/expr "${SSH_PORT}" + 1)"
                rule_wireguard='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"UDP","ports":"'${secure_port}'"},{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        else
                if [ -f "${firewall_dat}" ] && [ -n "$(/bin/grep "^REVERSEPROXYPORTS:" "${firewall_dat}" | /bin/grep cloudflare)" ] && [ -n "${all_dns_proxy_ips}" ]
                then
                        rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
                fi
        fi

        rule_vpc_ssl='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        if [ "${BUILD_MACHINE_VPC}" = "0" ]
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if [ "${NO_REVERSE_PROXIES}" != "0" ]
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
fi

if [ -n "$( /bin/echo "${firewall_name}" | /bin/grep "adt-webserver" )" ]
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${webserver_firewall_ports}")"
        rule_vpc_ssl='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'

        if [ "${NO_REVERSE_PROXIES}" = "0" ]
        then
                if [ -f "${firewall_dat}" ] && [ -n "$(/bin/grep "^WEBSERVERPORTS:" "${firewall_dat}" | /bin/grep cloudflare)" ] && [ -n "${all_dns_proxy_ips}" ]
                then
                        rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"443"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"443"}'
                fi
        fi

        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        if [ "${BUILD_MACHINE_VPC}" = "0" ]
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if [ "${NO_REVERSE_PROXIES}" = "0" ]
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
fi

if [ -n "$( /bin/echo "${firewall_name}" | /bin/grep "adt-database" )" ]
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${database_firewall_ports}")"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_vpc_db='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${DB_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        if [ "${BUILD_MACHINE_VPC}" = "0" ]
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

if [ -n "${rule_build_machine}" ]
then
        rule_build_machine="${rule_build_machine},"
fi

if [ -n "${rule_build_machine_ssl}" ]
then
        rule_build_machine_ssl="${rule_build_machine_ssl},"
fi

if [ -n "${rule_wireguard}" ]
then
        rule_wireguard="${rule_wireguard},"
fi

if [ -n "${rule_vpc_ssh}" ]
then
        rule_vpc_ssh="${rule_vpc_ssh},"
fi

if [ -n "${rule_vpc_db}" ]
then
        rule_vpc_db="${rule_vpc_db},"
fi

if [ -n "${rule_vpc_ssl}" ]
then
        rule_vpc_ssl="${rule_vpc_ssl},"
fi

if [ -n "${rule_ssl}" ]
then
        rule_ssl="${rule_ssl},"
fi

if [ -n "${rule_icmp}" ]
then
        rule_icmp="${rule_icmp},"
fi

if [ -n "${firewall_rules}" ]
then
        firewall_rules="${firewall_rules},"
fi

ruleset="$(/bin/echo "${rule_build_machine}${rule_build_machine_ssl}${rule_wireguard}${rule_vpc_ssh}${rule_vpc_db}${rule_vpc_ssl}${rule_ssl}${rule_icmp}${firewall_rules}" | /bin/sed 's/,$//g')"
ruleset='['${ruleset}']'

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}" 
        exit 1
fi

# Execute target actions safely, tracking exits manually
set +e
firewall_id="$("${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/get_firewall_id.sh" "${firewall_name}")"

if [ -z "${firewall_id}" ] 
then
        firewall_id="$("${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/create_firewall.sh" "${firewall_name}")"
        if [ "$?" -ne 0 ] 
        then
                status "Failed to create firewall"
                exit 1
        fi
else
        "${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/reset_firewall.sh" "${firewall_id}"
        if [ "$?" -ne 0 ] 
        then
                status "Failed to reset firewall"
                exit 1
        fi
fi      

"${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/UpdateFirewall.sh" "${firewall_id}" "${ruleset}"
update_status="$?"
set -e

if [ "${update_status}" -ne 0 ] 
then
        status "Failed to update firewall"
        exit 1
fi

if [ -n "${firewall_id}" ]
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi

exit 0


