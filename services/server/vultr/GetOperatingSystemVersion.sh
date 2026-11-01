
buildos="${1}"
buildos_version="${2}"

if ( [ "${buildos}" = "ubuntu" ] )
then
  /bin/echo "Ubuntu ${buildos_version} LTS x64"
elif ( [ "${buildos}" = "debian" ] )
then
  /bin/echo "Debian ${buildos_version} x64"
fi
