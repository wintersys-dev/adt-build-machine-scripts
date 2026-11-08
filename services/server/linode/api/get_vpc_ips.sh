
token="${1}"
region="${2}"

/bin/echo "Authorization: Bearer ${token}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${region}'"}' "https://api.linode.com/v4/vpcs/ips"
