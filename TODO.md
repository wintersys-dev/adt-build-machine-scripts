1. integrate new installation technique
2. Refactor software.dat and inject it from config repository (on build machine first) and then once the securitymanager is in place clone the config
repository to the different machine types and pass the security sensitive parameters in through cloud init and distribute them to the different
machines through cloud-init. See what other config files such as scaling and so on I want to have in the repository. See if the webserver name can be removed from the template and just cue what webserver to install based on what is in software.dat. Just install using nala when available, binary if that's the only available option and install with a custom script (which can be compiling or just a bespoke repo setup like PHP) when needed. 
3. put in a callback mechanism into the cloud-init scripts to call back with status updates to the build machine so that the deployer knows what is happening with the cloud-init process
4. work out what I want to do with webserver configuration Maybe I can hold the webserver configurations in the config directory and then run custom snippets based on the server type. One generic config mechanism which can then be tailored or replaced based on what application is being installed. 
5. Rework the autoscaling stuff to read from a config file in the datastore which defines how many autoscalers how many init webservers how many reverse proxies and how many database VPS machines
6. install redis or an open source alternative on the database VPS and update firewall and so on
7. Create a Laptop repository which contains api based scripts to spin up a build machine rather than using the stackscript or cloud init. This script can
prompt the user for only the absolute essentials of what is needed such as api tokens and s3 keys and so on and once the user has been prompted the
script ask them if they want to store those credentials in a config file on their laptop so that on subsequent runs they simply type "deploy.sh" and
the script uses those parameters. Perhaps put in checks so that the credentials entered are shown to be valid such as being able to list s3buckets or or list machine types and so on
8. look into refactoring the usage of the s3 datastore, for example, ip addresses could be stored in the database rather than s3 which is more resilient or autoscaler machines could be used to keep an updated list of s3 addresses and each machine queries the autoscalers for the current list of ip addresses and caches them...there's options
9. See if the config directory can be operated without using the datastore maybe use rsync but that might be a bit tricky if a machine is offline. It might be easier to simply store the config directory in the datastore
10. Look into using the init webservers as gateway machines so that only their ip addresses need to be allowed access to the DBaaS system. This will use iptables masquerade.
11. Look into pushing the wireguard credentials to the authenticator machines from the webserver machines rather than using s3.
12. Redo the authenticator machines html pages and see if they can be made more secure
13. applications need to not have their config stored in outside_webroot instead the configs need to be in /var/www/html so review how the application
installation works
14. Refactor the Expedited.sh main script and make it so that the cloud-init script of the build machine is stored in BUILD_HOME and can be run as a cloud-init script or directly from the command line. Take out all the ISHARDCORE stuff and taks out that silly error handing stuff I was doing in the main script. Make Expedited so that all the initialisation stuff is done in a block and then once all the intialisation stuff is done consider it to be in an INITIALISED state and move it from an INITIALISED state to a BUILDING state and then FINALISING and then COMPLETED
15. 
  
  
