
get the application type file from the git repository to tell what type of application it is

curl -O https://raw.githubusercontent.com/adt-demos/communitybuilder-webroot-sourcecode-baseline/main/dbp.dat



need to interrogate these files on the build machine from the application repository


dbe.dat
applicationDB.sql
dba.dat
dbp.dat

Also, need to make it so that api clone_repository.sh can access a private repository (using a token) but that the token is removed when
a public repository is being accessed. might need to try one, fail and fall back to the other if the api is to complicated then
use the rediection technique to redirect to the cli 
