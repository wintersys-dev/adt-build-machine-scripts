#!/bin/sh

server_size="${1}"
server_name="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
DDOS_PROTECTION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ENABLE_DDOS_PROTECTION`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"
ACTIVE_FIREWALL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
SERVER_USER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"
BUILD_KEY="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}"


echo "1234" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chown root:root ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chmod 600 ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass

cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml"
machine_type="adt-webserver"
firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

linode_api_key="`/bin/cat /root/.config/linode-cli | /bin/grep '^token' | /usr/bin/awk '{print $NF}'`"
echo "linode_api_key: ${linode_api_key}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
unset linode_api_key


#ansible-vault encrypt --vault-password-file=${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml"

#linode_api_token="`/bin/cat /root/.config/linode-cli | /bin/grep '^token' | /usr/bin/awk '{print $NF}'`"
if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD ] )
then
        emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"
else
        emergency_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16`"
        /bin/echo "${emergency_password}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD
fi

#is this needed
ansible-galaxy collection install linode.cloud

#if ( [ "`/usr/local/bin/linode-cli vpcs list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`" = "" ] )
#then
#       /usr/local/bin/linode-cli vpcs create --no-defaults --label ${VPC_NAME} --region ${REGION} --subnets.label adt-subnet --subnets.ipv4 ${VPC_IP_RANGE}
#fi
#
#vpc_id="`/usr/local/bin/linode-cli vpcs list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`"
#subnet_id="`/usr/local/bin/linode-cli vpcs subnets-list ${vpc_id} --no-defaults --json  | /usr/bin/jq  -r '.[] | select (.label == "adt-subnet").id'`"
#

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

server_ips_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ips/${server_name}"
webserver_ready_file="/home/${SERVER_USER}/runtime/WEBSERVER_READY"
subnet_id_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ansible-vpc.yaml"
vpc_label: ${VPC_NAME}
vpc_region: ${REGION}
vpc_desc: "Main ADT infrastructure VPC created via Ansible"
subnetwork_label: "adt-subnet"
subnetwork_ipv4: "${VPC_IP_RANGE}"
subnetwork_desc: "Subnet for infrastructure servers"
subnet_id_file: ${subnet_id_file}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_vpc.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ansible-vpc.yaml"
subnet_id="`/bin/grep SUBNET_ID ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id | /usr/bin/awk -F'=' '{print $NF}'`"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ansible-${machine_type}.yaml"
server_name: ${server_name} 
region: ${REGION} 
server_size: ${server_size} 
image: ${image} 
emergency_password: ${emergency_password} 
firewall_id: ${firewall_id} 
subnet_id: ${subnet_id} 
path_to_user_data: ${cloud_config} 
server_user: ${SERVER_USER} 
server_ips_file: ${server_ips_file} 
build_key: ${BUILD_KEY} 
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_linode.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ansible-${machine_type}.yaml"
