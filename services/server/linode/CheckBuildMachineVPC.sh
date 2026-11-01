

# Input validation
if [ -z "${1}" ] 
then
        status "Error: buildmachine IP argument are required."
        status "Usage: $0 <buildmachine_ip>"
        exit 1
fi
