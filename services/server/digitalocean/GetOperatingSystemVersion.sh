

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
  buildos_version="$(/bin/echo ${buildos_version} | /bin/sed 's/\./-/g')"
  /bin/echo "ubuntu-${buildos_version}-x64"
elif ( [ "${buildos}" = "debian" ] )
then
  /bin/echo "debian-${buildos_version}-x64"
fi
