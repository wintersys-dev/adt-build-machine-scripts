set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ ! -d ${BUILD_HOME}/runtime/ansible-env ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/ansible-env
fi

python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"

apt update
apt install python${python_version}-venv

# 1. Create a virtual environment (e.g., named 'ansible-env')
python3 -m venv ${BUILD_HOME}/runtime/ansible-env

# 2. Activate the virtual environment
. ${BUILD_HOME}/runtime/ansible-env/bin/activate

# 3. Upgrade pip and install the requirements securely
pip install --upgrade pip

/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

if [ $? -eq 0 ] 
then
        cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
fi

pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt


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


echo "1234" > ${BUILD_HOME}/runtime/.ansible_vault_pass
chown root:root ${BUILD_HOME}/runtime/.ansible_vault_pass
chmod 600 ${BUILD_HOME}/runtime/.ansible_vault_pass

cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml"
machine_type="adt-webserver"
firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

linode_api_key="`/bin/cat /root/.config/linode-cli | /bin/grep '^token' | /usr/bin/awk '{print $NF}'`"
echo "linode_api_key: ${linode_api_key}" > ${BUILD_HOME}/runtime/.ansible_vault.yml
unset linode_api_key

ansible-vault encrypt --vault-password-file=${BUILD_HOME}/runtime/.ansible_vault_pass "${BUILD_HOME}/runtime/.ansible_vault.yml"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD ] )
then
        emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"
else
        emergency_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16`"
        /bin/echo "${emergency_password}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD
fi

#is this needed
ansible-galaxy collection install linode.cloud

if ( [ "`/usr/local/bin/linode-cli vpcs list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`" = "" ] )
then
        /usr/local/bin/linode-cli vpcs create --no-defaults --label ${VPC_NAME} --region ${REGION} --subnets.label adt-subnet --subnets.ipv4 ${VPC_IP_RANGE}
fi

vpc_id="`/usr/local/bin/linode-cli vpcs list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`"
subnet_id="`/usr/local/bin/linode-cli vpcs subnets-list ${vpc_id} --no-defaults --json  | /usr/bin/jq  -r '.[] | select (.label == "adt-subnet").id'`"

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

server_ips_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ips/${server_name}"
webserver_ready_file="/home/${SERVER_USER}/runtime/WEBSERVER_READY"
ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_linode.yaml -e "server_name=${server_name} region=${REGION} server_size=${server_size} image=${image} emergency_password=${emergency_password} firewall_id=${firewall_id} subnet_id=${subnet_id} path_to_user_data=${cloud_config} server_user=${SERVER_USER} server_ips_file=${server_ips_file} build_key=${BUILD_KEY} path_to_vault_file=${BUILD_HOME}/runtime/.ansible_vault.yml"
