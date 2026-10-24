

authentication_token="${1}" 
repository_username="${2}"
repository_ownername="${3}" 
repository_name="${4}" 

/usr/bin/git ls-remote https://${repository_username}${authentication_token}@github.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
