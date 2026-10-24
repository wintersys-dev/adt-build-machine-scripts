
/usr/bin/git ls-remote https://${repository_username}${authentication_token}@gitlab.com/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
