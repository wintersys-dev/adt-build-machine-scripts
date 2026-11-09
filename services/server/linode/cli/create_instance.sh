#!/bin/sh

BUILD_HOME=$(cat /home/buildhome.dat)
CLOUDHOST=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)
BUILD_IDENTIFIER=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)
TOKEN=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)
parameter_payload=${1}

# POSIX-compliant way to read from a variable using a standard Here-Doc
read -r region image server_size server_name firewall_id subnet_id user_data_path <<EOF
$parameter_payload
EOF

export LINODE_CLI_TOKEN="${TOKEN}"

password_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then    
        emergency_password=$(cat "${password_file}")
else
        # POSIX-compatible random string generation
        emergency_password=$(/usr/bin/openssl rand -base64 32 2>/dev/null | tr -d '\n' | tr -cd 'a-zA-Z0-9' | cut -c 1-16)
        echo "${emergency_password}" > "${password_file}"
fi

interfaces=$(/usr/bin/jq -n --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')

# POSIX-compatible base64 encoding without GNU-specific wrapping flags
ENCODED_USER_DATA=$(/usr/bin/base64 < "${user_data_path}" | tr -d '\n')

# mktemp is not strictly POSIX, but widely available. 
# If mktemp fails, we use a POSIX-safe fallback path.
if command -v mktemp >/dev/null 2>&1; then
        TMP_CONFIG=$(mktemp)
else
        TMP_CONFIG="/tmp/linode_cfg_$$"
fi

touch "${TMP_CONFIG}"
chmod 600 "${TMP_CONFIG}"

cat <<EOF > "${TMP_CONFIG}"
[linode-cli]
root_pass = ${emergency_password}
region = ${region}
image = ${image}
type = ${server_size}
label = ${server_name}
interfaces = ${interfaces}
metadata.user_data = ${ENCODED_USER_DATA}
disk_encryption = enabled
EOF

# Execute linode-cli using the configuration file
/usr/local/bin/linode-cli --no-defaults --json linodes create --config "${TMP_CONFIG}" --no-defaults --interface_generation linode

# POSIX fallback: shred is non-standard, use rm -f directly
rm -f "${TMP_CONFIG}"
