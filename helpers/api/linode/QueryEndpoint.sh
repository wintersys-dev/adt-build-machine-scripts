# 1. Setup the pre-flight token check
if [ -z "${TOKEN}" ]; then
    echo "Error: TOKEN variable is empty." >&2
    exit 1
fi

# 2. Execute the fetch, appending the HTTP code on a new trailing line
# Note: we REMOVED '-f' so we can capture the body payload on 4xx/5xx errors
raw_output=$(printf "header = \"Authorization: Bearer %s\"\n" "${TOKEN}" | \
  curl -m 10 -s -S -K - "https://linode.com" \
  -w "\n%{http_code}")

# 3. Check curl's exit code for protocol or network layer drops
if [ $? -ne 0 ]; then
    echo "Critical: Network connection or curl execution failed entirely." >&2
    exit 1
fi

# 4. Extract the HTTP Status Code (the last line) and the API response Body (everything else)
http_status=$(echo "$raw_output" | tail -n 1)
response_body=$(echo "$raw_output" | sed '$d')

# 5. Evaluate the HTTP response classes
if [ "$http_status" -ne 200 ]; then
    echo "API Error: Received HTTP status code ${http_status}" >&2
    echo "Server Error Body: ${response_body}" >&2
    
    # Take specific actions based on the response status code
    case "$http_status" in
        401|403) echo "Authentication issue: Verify your TOKEN validity." >&2 ;;
        429)     echo "Rate limited: Backing off before retrying..." >&2 ;;
        500|503) echo "Linode API side breakdown. Try again later." >&2 ;;
    esac
    exit 1
fi

# 6. Proceed safely with valid payload processing
if ! echo "$response_body" | jq empty 2>/dev/null; then
    echo "Error: HTTP status was 200, but data stream payload is corrupted JSON." >&2
    exit 1
fi

echo "Success! Processing instances list..."
