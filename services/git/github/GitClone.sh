#!/bin/sh

#put in error checking here

authentication_token="${1}" 
repository_username="${2}"
repository_ownername="${3}" 
repository_name="${4}" 

/usr/bin/git clone --depth 1 https://${repository_username}${authentication_token}@github.com/${repository_ownername}/${repository_name}.git

