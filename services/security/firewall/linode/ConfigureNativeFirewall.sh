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
#set -x

firewall_name="${1}"
machine_type="`/bin/echo ${firewall_name} | /bin/sed 's/adt-//'`"
machine_type_upper="`/bin/echo ${machine_type} | /usr/bin/tr '[:lower:]' '[:upper:]'`"

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
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
build_machine_ip="`${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh`"

firewall_name="${firewall_name}-${BUILD_IDENTIFIER}"

vault_password_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass"
vault_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml"
inventory="${BUILD_HOME}/services/security/firewall/linode/ansible/inventory.ini"

. ${BUILD_HOME}/runtime/ansible-env/bin/activate 

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-delete_rules.yaml"
target_firewall_label:${firewall_name}
path_to_vault_file: ${vault} 
EOF

ansible-playbook --vault-password-file ${vault_password_file} -i ${BUILD_HOME}/services/security/firewall/linode/ansible/inventory.ini ${BUILD_HOME}/services/security/firewall/linode/ansible/delete_rules_from_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-delete_rules.yaml"

if ( [ "${firewall_name}" = "adt-authenticator" ] )
then
        all_dns_proxy_ips="`${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh "auth"`"
else
        all_dns_proxy_ips="`${BUILD_HOME}/services/dns/GetProxyDNSIPs.sh`"
fi

firewall_rules="`/bin/grep "^${machine_type_upper}PORTS" ${BUILD_HOME}/configuration/firewall.dat | /usr/bin/awk -F':' '{print $2}'`"
if ( [ "${firewall_rules}" != "" ] )
then
        rule_port="`/bin/echo ${firewall_rules} | /usr/bin/awk -F'|' '{print $1}'`"
        rule_protocol="`/bin/echo ${firewall_rules} | /usr/bin/awk -F'|' '{print $3}'`"
        rule_ipv4_addresses="`/bin/echo ${firewall_rules} | /usr/bin/awk -F'|' '{print $4}'`"
        rule_action="`/bin/echo ${firewall_rules} | /usr/bin/awk -F'|' '{print $5}'`"
        no_rules="`/bin/echo ${firewall_rules} | /usr/bin/wc -w`"

        for rule_no in ${no_rules}
        do
                if ( [ "${rule_ipv4_addresses}" = "cloudflare" ] )
                then
                        rule_ipv4_addresses="[${all_dns_proxy_ips}]"
                fi

                cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-custom_rule-${rule_no}.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER} 
rule_name: custom_rule-${rule_no}
rule_action: ACCEPT
rule_port: ${rule_port}
rule_protocol: ${rule_protocol}
rule_ipv4_addresses: ${rule_ipv4_addresses}
path_to_vault_file: ${vault} 
EOF
ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-custom_rule-${rule_no}.yaml"
        done
fi


cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_vpc_ssh.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_vpc_ssh
rule_action: ACCEPT
rule_port: ${SSH_PORT}
rule_protocol: TCP
rule_ipv4_addresses: ${VPC_IP_RANGE}
path_to_vault_file: ${vault} 
EOF

ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_vpc_ssh.yaml"

if ( [ "${machine_type}" = "database" ] )
then
        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_vpc_db.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_db_ssh
rule_action: ACCEPT
rule_port: ${DB_PORT}
rule_protocol: TCP
rule_ipv4_addresses: ${VPC_IP_RANGE}
path_to_vault_file: ${vault} 
EOF

ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory}  ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_vpc_db.yaml"
fi


cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_icmp.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_icmp
rule_action: ACCEPT
rule_protocol: ICMP
rule_ipv4_addresses: 0.0.0.0/0
path_to_vault_file: ${vault} 
EOF

ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_icmp.yaml"

if ( [ "${machine_type}" = "authenticator" ] || ( [ "${machine_type}" = "reverseproxy" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] ) || ( [ "${machine_type}" = "webserver" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] ) )
then
        if ( [ "${all_dns_proxy_ips}" = "" ] )
        then
                rule_ipv4_addresses="0.0.0.0/0"
        else
                rule_ipv4_addresses="[${all_dns_proxy_ips}]" 
        fi
        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_ssl_tcp.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_ssl_tcp
rule_action: ACCEPT
rule_port: 443
rule_protocol: TCP
rule_ipv4_addresses: ${rule_ipv4_addresses}
path_to_vault_file: ${vault} 
EOF
        ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_ssl_tcp.yaml"

        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_ssl_udp.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_ssl_udp
rule_action: ACCEPT
rule_port: 443
rule_protocol: UDP
rule_ipv4_addresses: ${rule_ipv4_addresses}
path_to_vault_file: ${vault} 
EOF
        ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_ssl_udp.yaml"
fi

if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] && [ "${machine_type}" = "reverseproxy" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] )
then
        wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"
        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-wireguard.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_wireguard
rule_action: ACCEPT
rule_port: ${wireguard_port}
rule_protocol: TCP
rule_ipv4_addresses: ${rule_ipv4_addresses}
path_to_vault_file: ${vault} 
EOF

        ansible-playbook --vault-password-file ${vault_password_file}  -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-wireguard.yaml"
fi

if ( [ "${BUILD_MACHINE_VPC}" = "0" ] )
then
        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_build_machine.yaml"
firewall_name: ${firewall_name}-${BUILD_IDENTIFIER}  
rule_name: rule_build_machine
rule_action: ACCEPT
rule_port: ${SSH_PORT}
rule_protocol: TCP
rule_ipv4_addresses: ${build_machine_ip}/32
path_to_vault_file: ${vault} 
EOF

ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/update_firewall.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-rule_build_machine.yaml"
fi

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${firewall_name}-get_id.yaml"
firewall_name: "${firewall_name}-${BUILD_IDENTIFIER}" 
path_to_vault_file: ${vault} 
EOF

firewall_id="`ansible-playbook --vault-password-file ${vault_password_file} -i ${inventory} ${BUILD_HOME}/services/security/firewall/linode/ansible/get_firewall_id.yaml -e @/home/agile-deployer/adt-build-machine-scripts/runtime/linode/test-build/playbooks/ansible-${firewall_name}-get_id.yaml | grep '"msg":' | grep -oE '[0-9]+'`"

if ( [ "$?" = "0" ] )
then
        /bin/echo "ADT_FIREWALL_ID:${firewall_id}"
fi
