# 1. Correctly capture the command output using command substitution $( ... )
available_engines=$(/usr/local/bin/linode-cli databases engines --json | jq -r '.[].id' 2>/dev/null)

# 2. Check the command exit status OR if the returned string is empty
if [ $? -ne 0 ] || [ -z "$available_engines" ]; then
    status "Failed to obtain list of available engines"
    exit 1
fi

# 3. Check if the requested engine exists in the list using a standard bash regex match
# (Alternatively, you can export available_engines or echo it if the calling script captures it)
if ! echo "$available_engines" | /bin/grep -q -w "${engine}"; then
    status "The database engine you have selected is not available please correct and re deploy"
    exit 1
fi

# 4. Return the result to the calling script by printing it to standard output
echo "$available_engines"
