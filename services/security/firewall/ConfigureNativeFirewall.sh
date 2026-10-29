#!/bin/sh
######################################################################################################
# @brief       Orchestrates the platform-specific native firewall generation and configuration process.
# @details     This script acts as a high-level wrapper that reads multi-tier architecture profiles 
#              (Authenticators, Autoscalers, Reverse Proxies, Web Servers, Databases) to determine proper 
#              network isolation rules. It constructs a complex JSON ruleset dynamically—injecting target 
#              VPC IP ranges, secure ports, build machine overrides, and custom whitelists—and hands execution 
#              off to the native script corresponding to the active cloud provider infrastructure.
# @param       1 (firewall_name) The architectural role name (e.g., adt-authenticator, adt-webserver) used 
#                                to evaluate specific conditional rulesets.
# @env         BUILD_HOME        The path to the installation directory of the deployment toolkit.
# @env         CLOUDHOST         The specific cloud platform active for this build target (e.g., linode).
# @exit        0                 Success. The platform ruleset was computed and successfully dispatched.
# @exit        1                 Failure. Generated if arguments are missing, structural configuration 
#                                files are unreadable, or downstream execution fails.
#######################################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x
set -e

linode_firewall_rules () {
        firewall_name="${1}"
        firewall_ports="${2}"
        firewall_rules=""
        for firewall_port_token in ${firewall_ports}
        do
                if ( [ "`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $2}'`" = "ipv4" ] )
                then
                        port="`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $1}'`"
                        ip_address="`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $4}'`"

                        if ( [ "`/usr/bin/ipcalc ${ip_address} | /bin/grep "INVALID"`"  = "" ] )
                        then
                                firewall_rules=${firewall_rules}'{"addresses":{"ipv4":["'${ip_address}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${port}'"},{"addresses":{"ipv4":["'${ip_address}'"]},"action":"ACCEPT","protocol":"UDP","ports":"'${port}'"}'
                        fi
                fi
        done
        /bin/echo "${firewall_rules}"
}

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

BUILD_HOME="$(/bin/cat /home/buildhome.dat)" 
ACTIVE_FIREWALLS="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS)"
CLOUDHOST="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST)"
BUILD_IDENTIFIER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER)"
BUILD_MACHINE_VPC="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_MACHINE_VPC)"
SSH_PORT="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT)"
DB_PORT="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_PORT)"
VPC_IP_RANGE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE)"
NO_REVERSE_PROXIES="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh NO_REVERSE_PROXIES)"
REGION="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION)"
BUILD_MACHINE_VPC="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_MACHINE_VPC)"
AUTHENTICATOR_TYPE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTHENTICATOR_TYPE)"
build_machine_ip="$(${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh)"

if ( [ -f ${BUILD_HOME}/configuration/firewall.dat ] )
then
        authenticator_firewall_ports="$(/bin/grep "^AUTHENTICATORPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}')"
        autoscaler_firewall_ports="$(/bin/grep "^AUTOSCALERPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}')"
        reverseproxy_firewall_ports="$(/bin/grep "^REVERSEPROXYPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}')"
        webserver_firewall_ports="$(/bin/grep "^WEBSERVERPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}')"
        database_firewall_ports="$(/bin/grep "^DATABASEPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}')"
fi

if ( [ "${firewall_name}" = "adt-authenticator" ] )
then
        all_dns_proxy_ips="$(${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh "yes")"
else
        all_dns_proxy_ips="$(${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh "no")"
fi

if ( [ "$(/bin/echo ${firewall_name} | /bin/grep "adt-authenticator")" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${authenticator_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        if ( [ "$(/bin/grep "^AUTHENTICATORPORTS:" ${BUILD_HOME}/configuration/firewall.dat | /bin/grep cloudflare)" != "" ] && [ "${all_dns_proxy_ips}" != "" ] )
        then
                rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'443'"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"'443'"}'
        fi

        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

if ( [ "$(/bin/echo ${firewall_name} | /bin/grep "adt-autoscaler")" != "" ] )
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${autoscaler_firewall_ports}")"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

if ( [ "$(/bin/echo ${firewall_name} | /bin/grep "adt-reverseproxy")" != "" ] )
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${reverseproxy_firewall_ports}")"

        rule_wireguard=""
        rule_ssl=""
        if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
        then
                secure_port="$(/usr/bin/expr ${SSH_PORT} + 1)"
                rule_wireguard='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"UDP","ports":"'${secure_port}'"},{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        else
                if ( [ "$(/bin/grep "^REVERSEPROXYPORTS:" ${BUILD_HOME}/configuration/firewall.dat | /bin/grep cloudflare)" != "" ] && [ "${all_dns_proxy_ips}" != "" ] )
                then
                        rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'443'"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"'443'"}'
                fi
        fi

        rule_vpc_ssl='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'443'"}'
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        rule_build_machine=""
        rule_build_machine_ssl=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if ( [ "${NO_REVERSE_PROXIES}" != "0" ] )
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-webserver"`" != "" ] )
then
        firewall_rules="$(linode_firewall_rules "${firewall_name}" "${webserver_firewall_ports}")"
        rule_vpc_ssl='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'443'"}'

        if ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
        then
                if ( [ "$(/bin/grep "^WEBSERVERPORTS:" ${BUILD_HOME}/configuration/firewall.dat | /bin/grep cloudflare)" != "" ] && [ "${all_dns_proxy_ips}" != "" ] )
                then
                        rule_ssl='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'443'"},{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"'443'"}'
                fi
        fi

        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'

        rule_build_machine=""
        rule_build_machine_ssl=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
                if ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_build_machine_ssl='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"443"}'
                fi
        fi
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
fi

if ( [ "$(/bin/echo ${firewall_name} | /bin/grep "adt-database")" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${database_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_vpc_db='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${DB_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi
fi

ruleset=""
if ( [ "${rule_build_machine}" != "" ] )
then
        rule_build_machine="${rule_build_machine},"
fi

if ( [ "${rule_build_machine_ssl}" != "" ] )
then
        rule_build_machine_ssl="${rule_build_machine_ssl},"
fi

if ( [ "${rule_wireguard}" != "" ] )
then
        rule_wireguard="${rule_wireguard},"
fi

if ( [ "${rule_vpc_ssh}" != "" ] )
then
        rule_vpc_ssh="${rule_vpc_ssh},"
fi

if ( [ "${rule_vpc_db}" != "" ] )
then
        rule_vpc_db="${rule_vpc_db},"
fi

if ( [ "${rule_vpc_ssl}" != "" ] )
then
        rule_vpc_ssl="${rule_vpc_ssl},"
fi

if ( [ "${rule_ssl}" != "" ] )
then
        rule_ssl="${rule_ssl},"
fi

if ( [ "${rule_icmp}" != "" ] )
then
        rule_icmp="${rule_icmp},"
fi

if ( [ "${firewall_rules}" != "" ] )
then
        firewall_rules="${firewall_rules},"
fi

ruleset="$(/bin/echo ${rule_build_machine}${rule_build_machine_ssl}${rule_wireguard}${rule_vpc_ssh}${rule_vpc_db}${rule_vpc_ssl}${rule_ssl}${rule_icmp}${firewall_rules} | /bin/sed 's/,$//g')"
ruleset='['${ruleset}']'

software_file="${BUILD_HOME}/configuration/software.dat"
if ( [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ] )
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if ( [ "${orchestration_tool}" = "" ] )
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_tool}" 
        exit 1
fi

script_path="${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/ConfigureNativeFirewall.sh"

if ( [ ! -f "${script_path}" ] )
then
        status "Error: Script not found at ${script_path}"
        exit 1
fi

if ( [ ! -x "${script_path}" ] )
then
        status "Error: Script at ${script_path} is not executable."
        exit 1
fi

/bin/echo "$("${script_path}" "${firewall_name}" "${ruleset}")"  

exit_code=$?

if ( [ ${exit_code} -ne 0 ] )
then
        status "Error: ConfigureNativeFirewall.sh failed with exit code $exit_code"
        exit $exit_code
fi
