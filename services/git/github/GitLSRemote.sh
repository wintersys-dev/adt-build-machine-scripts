/usr/bin/git ls-remote https://${repository_username}${authentication_token}@github.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
