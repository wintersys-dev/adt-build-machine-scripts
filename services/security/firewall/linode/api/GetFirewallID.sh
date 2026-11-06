

firewall_name="${1}"



/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/networking/firewalls" | jq -r --arg name "${firewall_name}" --arg build "-${BUILD_IDENTIFIER}" '.data[] | select(.label | contains($name)) | select(.label | endswith($build)).id'
