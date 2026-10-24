

repository_provider="${1}" 
authentication_token="${2}" 
repository_username="${3}"
repository_ownername="${4}" 
repository_name="${5}" 

/usr/bin/git ls-remote https://${repository_username}${authentication_token}@gitlab.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
