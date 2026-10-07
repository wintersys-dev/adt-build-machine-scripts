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

machine_type="adt-database"

RND="`/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1`"
database_name="db-${REGION}-${BUILD_IDENTIFIER}-${RND}"

. ${BUILD_HOME}/runtime/ansible-env/bin/activate

#/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

#if [ $? -eq 0 ] 
#then
#        cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
#linode_api4>=5.46.1
#polling==0.3.2
#ansible-specdoc>=0.0.20
#EOF
#fi

#pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt

echo "1234" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chown root:root ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chmod 600 ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass

if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml ] )
then
        /bin/sed -i "s/XXXXDATABASE_HOSTNAMEXXXX/${database_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml
        cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml"
fi

if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
then
        snapshot_id="`/bin/grep database ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
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

server_ips_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ips/${database_name}"
subnet_id_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id"

if ( [ ! -d ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks
fi

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-vpc-${machine_type}.yaml"
vpc_label: ${VPC_NAME}
vpc_region: ${REGION}
vpc_desc: "Main ADT infrastructure VPC created via Ansible"
subnetwork_label: "adt-subnet"
subnetwork_ipv4: "${VPC_IP_RANGE}"
subnetwork_desc: "Subnet for infrastructure servers"
subnet_id_file: ${subnet_id_file}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_vpc.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-vpc-${machine_type}.yaml"
subnet_id="`/bin/grep SUBNET_ID ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id | /usr/bin/awk -F'=' '{print $NF}'`"

root_domain="`/bin/echo ${WEBSITE_URL} | /usr/bin/cut -d'.' -f2,3`"
target_subdomain="`/bin/echo ${WEBSITE_URL} | /usr/bin/cut -d'.' -f1`"
ready_file="/home/${SERVER_USER}/runtime/DATABASE_READY"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_type}.yaml"
server_name: ${database_name}
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

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_linode.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_type}.yaml"

/bin/echo "Server IP Addresses for machine ${database_name} are available"
cat ${server_ips_file}
