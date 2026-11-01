

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Buildos and buildos_version arguments are required."
        status "Usage: $0 <buildos> <buildos_version>"
        exit 1
fi

buildos="${1}"
buildos_version="${2}"
  
if ( [ "${buildos}" = "ubuntu" ] )
then
  /bin/echo "linode/ubuntu${buildos_version}"
elif ( [ "${buildos}" = "debian" ] )
then
  /bin/echo "linode/debian${buildos_version}"
fi
