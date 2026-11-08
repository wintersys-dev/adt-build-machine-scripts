
token="${1}"
vpc_payload="${2}"
    
/bin/echo "Authorization: Bearer ${token}" | curl -H @- -f -s -X POST "https://api.linode.com/v4/vpcs" -H "Content-Type: application/json" -d "${vpc_payload}")"
