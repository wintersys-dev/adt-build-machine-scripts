#!/bin/sh

set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
DDOS_PROTECTION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ENABLE_DDOS_PROTECTION`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"
ACTIVE_FIREWALL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
NO_AUTOSCALERS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh NO_AUTOSCALERS`"
WS_SERVER_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WS_SERVER_TYPE`"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
SERVER_USER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"
BUILD_KEY="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"

machine_type="adt-webserver"

webserver_no="${1}"

if ( [ "${NO_AUTOSCALERS}" = "" ] )
then
        NO_AUTOSCALERS="0"
fi

no_autoscalers="${NO_AUTOSCALERS}"
webserver_index="${webserver_no}"

if ( [ "${no_autoscalers}" = "0" ] )
then
        autoscaler_no="0"
elif ( [ "${webserver_index}" -gt "${no_autoscalers}" ] )
then
        autoscaler_no="`/usr/bin/expr ${webserver_index} - ${no_autoscalers}`"
        while ( [ "${autoscaler_no}" -gt "${no_autoscalers}" ] )
        do
                autoscaler_no="`/usr/bin/expr ${webserver_index} - ${no_autoscalers}`"
                webserver_index="${autoscaler_no}"
        done
else
        autoscaler_no="${webserver_index}"
fi

RND="`/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1`"
webserver_name="ws-${REGION}-${BUILD_IDENTIFIER}-${autoscaler_no}-${RND}-init-${webserver_no}"

#. ${BUILD_HOME}/runtime/ansible-env/bin/activate
#
#/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt
#
#if [ $? -eq 0 ] 
#then
#        cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
#linode_api4>=5.46.1
#polling==0.3.2
#ansible-specdoc>=0.0.20
#EOF
#fi

#pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt

#echo "1234" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
#chown root:root ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
#chmod 600 ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass

. ${BUILD_HOME}/runtime/ansible-env/bin/activate

if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml ] )
then
        webserver_name_match="`/bin/echo ${webserver_name} | /usr/bin/awk -F'-' 'NF{NF--};1' | /bin/sed 's/ /-/g'`"
        /bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${webserver_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
        /bin/sed -i "s/${webserver_name_match}.*$/${webserver_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
        cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml"
fi

if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
then
        snapshot_id="`/bin/grep webserver ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
        ${BUILD_HOME}/helpers/services/SetVariableValue.sh SNAPSHOT_ID=${snapshot_id}
fi

firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD ] )
then
        emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"
else
        emergency_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16`"
        /bin/echo "${emergency_password}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD
fi

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml"
linode_api_token: ${TOKEN}
emergency_password: ${emergency_password} 
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-vault encrypt --vault-password-file=${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml"

#is this needed
ansible-galaxy collection install linode.cloud

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

server_ips_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ips/${webserver_name}"
#webserver_ready_file="/home/${SERVER_USER}/runtime/WEBSERVER_READY"
subnet_id_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id"

if ( [ ! -d ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks
fi

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-vpc-${machine_type}-${webserver_no}.yaml"
vpc_label: ${VPC_NAME}
vpc_region: ${REGION}
vpc_desc: "Main ADT infrastructure VPC created via Ansible"
subnetwork_label: "adt-subnet"
subnetwork_ipv4: "${VPC_IP_RANGE}"
subnetwork_desc: "Subnet for infrastructure servers"
subnet_id_file: ${subnet_id_file}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_vpc.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-vpc-${machine_type}-${webserver_no}.yaml"
subnet_id="`/bin/grep SUBNET_ID ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id | /usr/bin/awk -F'=' '{print $NF}'`"

root_domain="`/bin/echo ${WEBSITE_URL} | /usr/bin/cut -d'.' -f2,3`"
target_subdomain="`/bin/echo ${WEBSITE_URL} | /usr/bin/cut -d'.' -f1`"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-delete-dns-${machine_type}-${webserver_no}.yaml"
root_domain: ${root_domain}
target_subdomain: ${target_subdomain}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/STALE_DNS_PURGED ] )
then
        ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass  -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/delete_dns_records.yaml  -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-delete-dns-${machine_type}-${webserver_no}.yaml"
fi

if ( [ "$?" = "0" ] )
then
        /bin/touch ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/STALE_DNS_PURGED
fi

ready_file="/home/${SERVER_USER}/runtime/WEBSERVER_READY"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_type}-${webserver_no}.yaml"
server_name: ${webserver_name}
region: ${REGION} 
server_size: "${WS_SERVER_TYPE}" 
image: ${image} 
emergency_password: ${emergency_password} 
firewall_id: ${firewall_id} 
subnet_id: ${subnet_id} 
path_to_user_data: ${cloud_config} 
server_user: ${SERVER_USER} 
server_ips_file: ${server_ips_file} 
build_key: ${BUILD_KEY} 
ready_file: ${ready_file}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_linode.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_type}-${webserver_no}.yaml"

/bin/echo "Server IP Addresses for machine ${webserver_name} are available"
cat ${server_ips_file}

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-add-dns-${machine_type}-${webserver_no}.yaml"
root_domain: ${root_domain}
target_subdomain: ${target_subdomain}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ip_addresses="`/bin/grep PUBLIC_IP= ${server_ips_file} | /usr/bin/awk -F'=' '{print $NF}'`"

for ip_address in ${ip_addresses}
do
        ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass  -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/add_dns_record.yaml  -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-add-dns-${machine_type}-${webserver_no}.yaml" -e "ip_address=${ip_address}"
done

