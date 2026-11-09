set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
parameter_payload="${1}"

read -r region image server_size server_name firewall_id subnet_id user_data_path <<EOF
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

# FIX: Added the '-c' flag to compress the JSON string into one single continuous line
interfaces="$(/usr/bin/jq -c -n --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')"

ENCODED_USER_DATA=$(/usr/bin/base64 -w0 "${user_data_path}")


# ... [Keep your previous variable extractions and jq configurations exactly the same] ...

# 1. Base64 encode your user data into memory
ENCODED_USER_DATA=$(/usr/bin/base64 -w0 "${user_data_path}")

# 2. Open an isolated subshell and immediately assign the sensitive strings
# directly to the local positional parameter memory array ($1, $2, $3)
sh -c '
/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "$1" --region "$4" --image "$5" --type "$6" --label "$7" --interface_generation linode --interfaces "$2" --metadata.user_data "$3" --disk_encryption enabled
' -- "$emergency_password" "$interfaces" "$ENCODED_USER_DATA" "$region" "$image" "$server_size" "$server_name"


# Securely wipe local parent state structures
unset LINODE_CLI_TOKEN emergency_password region image server_size server_name interfaces user_data_path ENCODED_USER_DATA
