
buildos="${1}"
buildos_version="${2}"
  
if ( [ "${buildos}" = "ubuntu" ] )
then
  /bin/echo "linode/ubuntu${buildos_version}"
elif ( [ "${buildos}" = "debian" ] )
then
  /bin/echo "linode/debian${buildos_version}"
fi
