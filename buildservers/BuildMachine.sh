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
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
SERVER_USER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"
BUILD_KEY="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/keys/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"
NO_REVERSE_PROXIES="`${BUILD_HOME}/helpers/services/GetVariableValue.sh NO_REVERSE_PROXIES`"
NO_AUTHENTICATORS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh NO_AUTHENTICATORS`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"
AUTH_DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE`"
AUTH_SERVER_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL`"


machine_type="${1}" #for example adt-webserver
machine_identifier="${2}"  # for example ws
machine_identifier_upper="`/bin/echo ${machine_identifier} | /usr/bin/tr '[:lower:]' '[:upper:]'`"
machine_no="${3}" # 1
subnet_id="${4}"
machine_label="`/bin/echo ${machine_type} | /bin/sed 's/^adt-//'`"
machine_label_upper="`/bin/echo ${machine_label} | /usr/bin/tr '[:lower:]' '[:upper:]'`"
SERVER_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ${machine_identifier_upper}_SERVER_TYPE`"
unique_identifier="`/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1`"
emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"

if ( [ "${machine_type}" = "adt-authenticator" ] )
then
        machine_name="NO-${machine_no}-${machine_identifier}-${REGION}-${BUILD_IDENTIFIER}-${unique_identifier}"
fi

if ( [ "${machine_type}" = "adt-autoscaler" ] )
then
        machine_name="NO-${machine_no}-${machine_identifier}-${REGION}-${BUILD_IDENTIFIER}-${unique_identifier}"
fi

if ( [ "${machine_type}" = "adt-reverseproxy" ] )
then
        machine_name="NO-${machine_no}-${machine_identifier}-${REGION}-${BUILD_IDENTIFIER}-${unique_identifier}"
fi

if ( [ "${machine_type}" = "adt-webserver" ] )
then
        machine_name="${machine_identifier}-${REGION}-${BUILD_IDENTIFIER}-0-${unique_identifier}-init-${machine_no}"
fi

if ( [ "${machine_type}" = "adt-database" ] )
then
        machine_name="${machine_identifier}-${REGION}-${BUILD_IDENTIFIER}-${unique_identifier}"
fi

if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_label}.yaml ] )
then
        /bin/cp ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_label}.yaml ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_name}.yaml
        machine_name_match="`/bin/echo ${machine_name} | /usr/bin/awk -F'-' 'NF{NF--};1' | /bin/sed 's/ /-/g'`"
        /bin/sed -i "s/XXXX${machine_label_upper}_HOSTNAMEXXXX/${machine_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_name}.yaml
        /bin/sed -i "s/${machine_name_match}.*$/${machine_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_name}.yaml
        cloud_config="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_name}.yaml"
fi

. ${BUILD_HOME}/runtime/ansible-env/bin/activate

if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
then
        snapshot_id="`/bin/grep ${machine_type} ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
        ${BUILD_HOME}/helpers/services/SetVariableValue.sh SNAPSHOT_ID=${snapshot_id}
fi

firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

server_ips_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ips/${machine_name}"
subnet_id_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/subnet_id"

if ( [ ! -d ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks
fi

if ( ( [ "${machine_type}" = "adt-authenticator" ] && [ "${NO_AUTHENTICATORS}" != "0" ] ) || ( [ "${machine_type}" = "adt-webserver" ] && [ "${NO_REVERSE_PROXIES}" = "0" ] ) || ( [ "${machine_type}" = "adt-reverseproxy" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] ) )
then
        if ( [ "${machine_type}" = "adt-authenticator" ] )
        then
                website_url="${AUTH_SERVER_URL}"
                dns_provider="${AUTH_DNS_CHOICE}"
        else
                website_url="${WEBSITE_URL}"
                dns_provider="${DNS_CHOICE}"
        fi
        target_subdomain="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f1`"
        root_domain="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2,3`"

        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-delete-dns-${machine_name}.yaml"
full_domain: ${website_url}
root_domain: ${root_domain}
target_subdomain: ${target_subdomain}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF

if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/STALE_DNS_PURGED-${machine_type} ] )
then
        ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass  -i ${BUILD_HOME}/services/server/ansible/${dns_provider}/inventory.ini ${BUILD_HOME}/services/server/ansible/cloudflare/delete_dns_records.yaml  -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-delete-dns-${machine_name}.yaml"
fi

if ( [ "$?" = "0" ] )
then
        /bin/touch ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/STALE_DNS_PURGED-${machine_type}
fi
fi

ready_file="/home/${SERVER_USER}/runtime/`/bin/echo ${machine_label} | /usr/bin/tr '[:lower:]' '[:upper:]'`_READY"

cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_name}.yaml"
server_name: ${machine_name}
region: ${REGION} 
server_size: "${SERVER_TYPE}" 
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

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/linode/create_linode.yaml -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-${machine_name}.yaml" 2>&1

/bin/echo "Server IP Addresses for machine ${machine_name} are available"
cat ${server_ips_file}

if ( ( [ "${machine_type}" = "adt-authenticator" ] && [ "${NO_AUTHENTICATORS}" != "0" ] ) || ( [ "${machine_type}" = "adt-webserver" ] && [ "${NO_REVERSE_PROXIES}" = "0" ] ) || ( [ "${machine_type}" = "adt-reverseproxy" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] ) )
then        
        if ( [ "${machine_type}" = "adt-authenticator" ] )
        then
                website_url="${AUTH_SERVER_URL}"
                dns_provider="${AUTH_DNS_CHOICE}"       
        else
                website_url="${WEBSITE_URL}"
                dns_provider="${DNS_CHOICE}"
        fi

        target_subdomain="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f1`"
        root_domain="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2,3`"

        cat << EOF > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-add-dns-${machine_name}.yaml"
root_domain: ${root_domain}
full_domain: ${website_url}
target_subdomain: ${target_subdomain}
path_to_vault_file: ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault.yaml
EOF
dns_provider="linode"

if ( ( [ "${AUTH_DNS_CHOICE}" = "cloudflare" ] && [ "${machine_type}" = "adt-authenticator" ] ) || ( [ "${DNS_CHOICE}" = "cloudflare" ] && ( [ "${machine_type}" = "adt-reverseproxy" ] || [ "${machine_type}" = "adt-webserver" ] ) ) )
then
        dns_provider="cloudflare"
fi

ip_address="`/bin/grep PUBLIC_IP= ${server_ips_file} | /usr/bin/awk -F'=' '{print $NF}'`"

ansible-playbook --vault-password-file ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/.ansible_vault_pass  -i ${BUILD_HOME}/services/server/ansible/linode/inventory.ini ${BUILD_HOME}/services/server/ansible/${dns_provider}/add_dns_record.yaml  -e "@${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/playbooks/ansible-add-dns-${machine_name}.yaml" -e "ip_address=${ip_address}"
fi
