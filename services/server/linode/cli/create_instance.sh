#!/bin/sh
set -x

BUILD_HOME=$(cat /home/buildhome.dat)
CLOUDHOST=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)
BUILD_IDENTIFIER=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)
TOKEN=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)
parameter_payload=${1}

read -r region image server_size server_name firewall_id subnet_id user_data_path <<EOF
$parameter_payload
EOF

export LINODE_CLI_TOKEN="${TOKEN}"

password_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then    
        emergency_password=$(cat "${password_file}")
else
        emergency_password=$(/usr/bin/openssl rand -base64 32 2>/dev/null | tr -d '\n' | tr -cd 'a-zA-Z0-9' | cut -c 1-16)
        echo "${emergency_password}" > "${password_file}"
fi

interfaces=$(/usr/bin/jq -n -c --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')


#We don't want  to pass the userdata on the command line as it will be visible in the process tree
ENCODED_USER_DATA=$(/usr/bin/base64 < "${user_data_path}" | tr -d '\n')

if [ ! -d "$HOME/.config" ]
then
        /bin/mkdir -p "$HOME/.config"
fi

TMP_CONFIG="$HOME/.config/linode-cli"

touch "${TMP_CONFIG}"
chmod 600 "${TMP_CONFIG}"

cat <<EOF > "${TMP_CONFIG}"
[linode-cli]
metadata.user_data = ${ENCODED_USER_DATA}
EOF

# Execute linode-cli using the configuration file
/usr/local/bin/linode-cli --json linodes create --region "${region}" --type "${server_size}" --label "${server_name}" --image "${image}" --interface_generation linode --interfaces "${interfaces}" --as-user "linode-cli" --root_pass "$(cat  ${password_file})" --disk_encryption "enabled"

rm -f "${TMP_CONFIG}"
