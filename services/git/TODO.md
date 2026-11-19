

test all the git changes I have made and slim down the interrogation process by not cloning the whole repository and only looking for specific files

need to see if the api method of cloning is a runner and also, all the CloneRepository.sh calls in various scripts on all machine types need to be tested
get the application type file from the git repository to tell what type of application it is

curl -O https://raw.githubusercontent.com/adt-demos/communitybuilder-webroot-sourcecode-baseline/main/dbp.dat

curl -L \
  -H "Authorization: Bearer YOUR_GITHUB_TOKEN" \
  -o dbp.dat \
  https://raw.githubusercontent.com/adt-demos/communitybuilder-webroot-sourcecode-baseline/main/dbp.dat

  or

  curl -L \
  -H "Authorization: Bearer YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw+json" \
  -o dbp.dat \
  https://api.github.com/repos/adt-demos/communitybuilder-webroot-sourcecode-baseline/contents/dbp.dat?ref=main

bitbucket

curl -O https://bitbucket.org/<workspace>/<repository>/raw/<branch>/<path-to-file>

curl -L -O https://api.bitbucket.org/2.0/repositories/myworkspace/myrepo/src/main/dbp.dat

curl -u "YOUR_EMAIL:YOUR_API_TOKEN" -L -O \
"https://api.bitbucket.org/2.0/repositories/myworkspace/myrepo/src/main/dbp.dat"

gitlab

curl -L -O https://gitlab.com/<group>/<project>/-/raw/main/dbp.dat

curl -L -O https://gitlab.com/adt-demos/communitybuilder-webroot-sourcecode-baseline/-/raw/main/dbp.dat


curl -L \
  --header "PRIVATE-TOKEN: YOUR_GITLAB_TOKEN" \
  -o dbp.dat \
  "https://gitlab.com/<group>/<project>/-/raw/main/dbp.dat"


  curl -L \
  --header "PRIVATE-TOKEN: YOUR_GITLAB_TOKEN" \
  -o dbp.dat \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/repository/files/dbp.dat/raw?ref=main"


need to interrogate these files on the build machine from the application repository


dbe.dat
applicationDB.sql
dba.dat
dbp.dat

Also, need to make it so that api clone_repository.sh can access a private repository (using a token) but that the token is removed when
a public repository is being accessed. might need to try one, fail and fall back to the other if the api is to complicated then
use the rediection technique to redirect to the cli 
