BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
parameter_payload="${1}"

read -r emergency_password region image server_size server_name firewall_id subnet_id user_data_encoded<<EOF
$parameter_payload
EOF

export LINODE_CLI_TOKEN="${TOKEN}"

read -s -p "Enter Linode Root Password: " LINODE_ROOT_PASS
echo ""

# 2. Safely read, encode, and export your userdata script to memory
export LINODE_METADATA__USER_DATA=$(base64 -w0 /path/to/your/cloud-config.yaml)

#see if interfaces can be made a parameter also

interfaces="$(/usr/bin/jq -n --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')"

/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "${emergency_password}" --region "${region}" --image "${image}" --type "${server_size}" --label "${server_name}" --no-defaults --interface_generation linode --interfaces "${interfaces}" --metadata.user_data "${user_data_encoded}" --disk_encryption enabled

unset LINODE_CLI_TOKEN
