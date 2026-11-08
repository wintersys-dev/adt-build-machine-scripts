BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
parameter_payload="${1}"

read -r emergency_password region image server_size server_name firewall_id subnet_id user_data_encoded<<EOF
$parameter_payload
EOF



instance_payload="$(/usr/bin/jq -n --arg pass "${EMERGENCY_PASSWORD}" --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data_encoded}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }')"


/bin/echo "Authorization: Bearer ${token}" | curl -H @- -f -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}"
