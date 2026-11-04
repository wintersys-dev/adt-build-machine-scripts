


database_id=$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | jq --arg lbl "$label" '.[] | select(.label | contains($lbl)) | .id' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$database_id" ]; then
    status "Database ID not available for label ${label}"
fi
