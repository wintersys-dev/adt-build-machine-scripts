
token="${1}"
instance_payload="${2}"

/usr/local/bin/linode-cli --no-defaults --json linodes create "${instance_payload}"
