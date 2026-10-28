#!/bin/sh
# Strict error handling for POSIX shell
set -e

emergency_password="${1}"
region="${2}"
image="${3}"
server_size="${4}"
server_name="${5}"
subnet_id="${6}"
user_data="${7}"
firewall_active="${8}"

# 2. Dynamic conditional handling for the optional firewall entry
if [ -n "$firewall_active" ]; then
    FIREWALL_JSON="${firewall_active},"
else
    FIREWALL_JSON=""
fi

# 3. Safely construct the JSON payload using printf to avoid quoting issues
PAYLOAD=$(printf '{
  "root_pass": "%s",
  "region": "%s",
  "image": "%s",
  "type": "%s",
  "label": "%s",
  "interface_generation": "linode",
  "interfaces": [
    {
      %s
      "vpc": {
        "subnet_id": %s,
        "ipv4": {
          "addresses": [
            {
              "address": "auto",
              "nat_1_1_address": "auto"
            }
          ]
        }
      }
    }
  ],
  "metadata": {
    "user_data": "%s"
  },
  "disk_encryption": "enabled"
}' \
"$emergency_password" \
"$REGION" \
"$image" \
"$server_size" \
"$server_name" \
"$FIREWALL_JSON" \
"$subnet_id" \
"$user_data")

# 4. Safe network call and response parsing without using 'pipefail' or 'tail'
echo "Creating Linode instance: ${server_name}..."

# We write output to a temporary file since POSIX lacks standard pipes that preserve exit codes
TMP_OUT=$(mktemp)

# Append the HTTP status code directly to the last line of the payload output
curl -s -X POST https://linode.com \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -w "\n%{http_code}" \
  -d "$PAYLOAD" > "$TMP_OUT"

# Extract status code and body using standard POSIX sed commands
HTTP_STATUS=$(sed -n '$p' "$TMP_OUT")
RESPONSE_BODY=$(sed '$d' "$TMP_OUT")
rm -f "$TMP_OUT"

# 5. Evaluate the API outcome
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
    echo "Success! Server created successfully."
    printf "%s\n" "$RESPONSE_BODY"
else
    echo "Error: Linode API returned status code ${HTTP_STATUS}" >&2
    echo "Response Details:" >&2
    printf "%s\n" "$RESPONSE_BODY" >&2
    exit 1
fi
