BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
parameter_payload="${1}"

read -r region image server_size server_name firewall_id subnet_id user_data_path<<EOF
$parameter_payload
EOF

export LINODE_CLI_TOKEN="${TOKEN}"

password_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then    
        emergency_password="$(/bin/cat "${password_file}")"
else
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16)"
        /bin/echo "${emergency_password}" > "${password_file}"
fi

export ENCODED_USER_DATA=$(/usr/bin/base64 -w0 ${user_data_path})

ENV_ARGS="--metadata.user_data=${ENCODED_USER_DATA}"
export LINODE_CLI_ARGS="${ENV_ARGS}"

interfaces="$(/usr/bin/jq -n --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')"

#/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "${emergency_password}" --region "${region}" --image "${image}" --type "${server_size}" --label "${server_name}" --no-defaults --interface_generation linode --interfaces "${interfaces}" --metadata.user_data "${user_data_encoded}" --disk_encryption enabled
/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "${emergency_password}" --region "${region}" --image "${image}" --type "${server_size}" --label "${server_name}" --no-defaults --interface_generation linode --interfaces "${interfaces}" --disk_encryption enabled

unset LINODE_CLI_ARGS ENCODED_USER_DATA ENV_ARGS
unset LINODE_CLI_TOKEN
