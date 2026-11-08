
token="${1}"
server_id="${2}"

/bin/echo "Authorization: Bearer ${token}" | curl -H @- -s -f -X POST "https://api.linode.com/v4/linode/instances/${server_id}/shutdown"
