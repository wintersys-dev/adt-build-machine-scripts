
token="${1}"
instance_payload="${2}"

/bin/echo "Authorization: Bearer ${token}" | curl -H @- -f -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}"
