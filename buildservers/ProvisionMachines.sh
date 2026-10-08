#!/bin/sh

set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"

. ${BUILD_HOME}/runtime/ansible-env/bin/activate

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

echo "1234" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chown root:root ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass
chmod 600 ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass

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
/bin/echo "Subnet ID set to: ${subnet_id}"

#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-authenticator" "auth" "1" "${subnet_id}"
#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-autoscaler" "as" "1" "${subnet_id}" 
#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-reverseproxy" "rp" "1" "${subnet_id}" 
#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-webserver" "ws" "1" "${subnet_id}" 
#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-webserver" "ws" "2" "${subnet_id}" 
#${BUILD_HOME}/buildservers/BuildMachine.sh "adt-database" "db" "1" "${subnet_id}" 
#exit

#for pid in ${pids}
#do
#        wait ${pid}
#done

pids=""
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-authenticator" "auth" "1" "${subnet_id}" &
pids="${pids} $!"
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-autoscaler" "as" "1" "${subnet_id}" &
pids="${pids} $!"
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-reverseproxy" "rp" "1" "${subnet_id}" &
pids="${pids} $!"
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-webserver" "ws" "1" "${subnet_id}" &
pids="${pids} $!"
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-webserver" "ws" "2" "${subnet_id}" &
pids="${pids} $!"
${BUILD_HOME}/buildservers/BuildMachine.sh "adt-database" "db" "1" "${subnet_id}" &
pids="${pids} $!"

for pid in ${pids}
do
        wait ${pid}
done



