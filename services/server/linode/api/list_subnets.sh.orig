
token="${1}"
vpc_id="${2}"

/bin/echo "Authorization: Bearer ${token}" | curl -H @- -f -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" |  /usr/bin/jq '.data'
