# The actual, functioning command:
RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    "https://api.linode.com/v4/networking/ips")
