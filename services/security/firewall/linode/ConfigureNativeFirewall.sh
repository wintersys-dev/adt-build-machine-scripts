#!/bin/sh
######################################################################################################
# Description: This will configure the native firewall to restrict access by ip address to our infrastructure
# according to what our configuration needs are. Sometimes machines are only accessible through the VPC they
# are in and sometimes they have to be accessible across the internet. The policy is designed to keep access
# to the machines as strict and as limited as possible. 
# Author: Peter Winter
# Date: 17/01/2021
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
set -x

linode_firewall_rules ()
{
        firewall_name="${1}"
        firewall_ports="${2}"
        firewall_rules=""
        for firewall_port_token in ${firewall_ports}
        do
                if ( [ "`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $2}'`" = "ipv4" ] )
                then
                        port="`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $1}'`"
                        ip_address="`/bin/echo ${firewall_port_token} | /usr/bin/awk -F'|' '{print $3}'`"
                        #Put  ipcalc in here?
                        if ( [ "`/bin/echo ${ip_address} | /bin/fgrep -o . | /usr/bin/wc -l`" = "3" ] )
                        then
                                firewall_rules=${firewall_rules}',{"addresses":{"ipv4":["'${ip_address}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${port}'"}'
                        fi
                fi
        done
        /bin/echo "${firewall_rules}"
}

firewall_name="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`" 
ACTIVE_FIREWALLS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
BUILD_MACHINE_VPC="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_MACHINE_VPC`"
SSH_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSH_PORT`"
DB_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_PORT`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
NO_REVERSE_PROXIES="`${BUILD_HOME}/helpers/services/GetVariableValue.sh NO_REVERSE_PROXIES`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
BUILD_MACHINE_VPC="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_MACHINE_VPC`"
AUTHENTICATOR_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTHENTICATOR_TYPE`"
build_machine_ip="`${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh`"


if ( [ -f ${BUILD_HOME}/configuration/firewall.dat ] )
then
        authenticator_firewall_ports="`/bin/grep "^AUTHENTICATORPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
        autoscaler_firewall_ports="`/bin/grep "^AUTOSCALERPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
        reverseproxy_firewall_ports="`/bin/grep "^REVERSEPROXYPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
        webserver_firewall_ports="`/bin/grep "^WEBSERVERPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
        database_firewall_ports="`/bin/grep "^DATABASEPORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
fi


secure_port="443"
if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] && [ "${firewall_name}" = "adt-reverseproxy" ]  )
then
        secure_port="`/usr/bin/expr ${SSH_PORT} + 1`"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-authenticator"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${authenticator_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'

        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi

        ruleset="${ruleset}${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-autoscaler"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${autoscaler_firewall_ports}"`"
        rule_vpc_ssh='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        rule_icmp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"ICMP"}'
        rule_build_machine=""
        if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
        then
                rule_build_machine='{"addresses":{"ipv4":["'${build_machine_ip}/32'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${SSH_PORT}'"}'
        fi

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi
        ruleset="${ruleset}${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-reverseproxy"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${reverseproxy_firewall_ports}"`"

        rule_secure_port_udp=""
        if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
        then
                rule_secure_port_udp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"UDP","ports":"'${secure_port}'"}'
        fi

        if ( [ "${all_dns_proxy_ips}" = "" ] )
        then
                rule_secure_port_tcp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        else
                rule_secure_port_tcp='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
        fi

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
        ruleset=""
        if ( [ "${rule_secure_port_udp}" != "" ] )
        then
                ruleset="${rule_secure_port_udp},"
        fi

        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine},"
        fi

        if ( [ "${rule_build_machine_ssl}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine_ssl},"
        fi

        ruleset="${ruleset}${rule_secure_port_tcp},${rule_vpc_ssh},${rule_icmp}${firewall_rules}"
fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-webserver"`" != "" ] )
then
        firewall_rules="`linode_firewall_rules "${firewall_name}" "${webserver_firewall_ports}"`"

        if ( [ "${all_dns_proxy_ips}" = "" ] )
        then
                if ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_secure_port_tcp='{"addresses":{"ipv4":["0.0.0.0/0"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                else
                        rule_secure_port_tcp='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
                fi
        else
                if  ( [ "${NO_REVERSE_PROXIES}" = "0" ] )
                then
                        rule_secure_port_tcp='{"addresses":{"ipv4":['${all_dns_proxy_ips}']},"action":"ACCEPT","protocol":"UDP","ports":"'${secure_port}'"}'
                else
                        rule_secure_port_tcp='{"addresses":{"ipv4":["'${VPC_IP_RANGE}'"]},"action":"ACCEPT","protocol":"TCP","ports":"'${secure_port}'"}'
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

        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine},"
        fi

        if ( [ "${rule_build_machine_ssl}" != "" ] )
        then
                ruleset="${ruleset}${rule_build_machine_ssl},"
        fi

        ruleset="${ruleset}${rule_secure_port_tcp},${rule_vpc_ssh},${rule_icmp}${firewall_rules}"

fi

if ( [ "`/bin/echo ${firewall_name} | /bin/grep "adt-database"`" != "" ] )
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

        ruleset=""
        if ( [ "${rule_build_machine}" != "" ] )
        then
                ruleset="${rule_build_machine},"
        fi

        ruleset="${ruleset}${rule_vpc_ssh},${rule_vpc_db},${rule_icmp}${firewall_rules}"
fi

ruleset='['${ruleset}']'

firewall_id="`/usr/local/bin/linode-cli --json firewalls list | /usr/bin/jq -r '.[] | select (.label | contains ("'${firewall_name}'")) |  select (.label | endswith ("'-${BUILD_IDENTIFIER}'")).id'`"

if ( [ "${firewall_id}" = "" ] )
then
        firewall_id="`/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP   --rules.outbound_policy ACCEPT | /usr/bin/jq -r '.[].id'`"
else
        /usr/local/bin/linode-cli firewalls rules-update --inbound '[]' --outbound '[]' --inbound_policy DROP --outbound_policy ACCEPT ${firewall_id}
fi

/usr/local/bin/linode-cli firewalls rules-update  --inbound ${ruleset} ${firewall_id}

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
