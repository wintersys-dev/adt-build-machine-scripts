
instance_payload="${1}"

/usr/local/bin/linode-cli --no-defaults --json linodes create "${instance_payload}"
