
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
