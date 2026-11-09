BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
parameter_payload="${1}"

read -r region image server_size server_name firewall_id subnet_id user_data_path<<EOF
$parameter_payload
EOF

password_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then    
        emergency_password="$(/bin/cat "${password_file}")"
else
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16)"
        /bin/echo "${emergency_password}" > "${password_file}"
fi

# 2. Safely read, encode, and export your userdata script to memory
user_data_encoded=$(/usr/bin/base64 -w0 ${user_data_path})

instance_payload="$(/usr/bin/jq -n --arg pass "${emergency_password}" --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data_encoded}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }')"
/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}"
