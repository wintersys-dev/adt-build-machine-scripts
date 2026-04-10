# README #

You can read about and find tutorials about the "Agile Deployment Toolkit" [here](https://www.wintersys-dev.uk)

-----------------------------

**${BUILD_HOME}/adt-build-machine-scripts/application**  
Here we have scripts related to the custom application that is being deployed, "Joomla, Wordpress, Drupal or Moodle"  

**${BUILD_HOME}/adt-build-machine-scripts/descriptors**  
This is where the descriptors are for the current build. You can make changes to the files that are here to configure a different build out  

**${BUILD_HOME}/adt-build-machine-scripts/build**  
These scripts will build different classes of server machine, for example, database, webserver or autoscaler machine types  

**${BUILD_HOME}/adt-build-machine-scripts/helpers**  
Utility scripts that can help you manage different workflows that your servers need  

**${BUILD_HOME}/adt-build-machine-scripts/initialisation**  
Initialisation scripts that intialised and configure different aspects of the build process  

**${BUILD_HOME}/adt-build-machine-scripts/installation**  
Scripts that install onto the build machine the software that is required for the build to succeed  

**${BUILD_HOME}/adt-build-machine-scripts/processing**  
Scripts that perform an pre or post processing that the current build run requires  

**${BUILD_HOME}/adt-build-machine-scripts/services**  
Scripts that relate to 3rd party services that the build depends on such as a git provider or a cloudhost provider  


**${BUILD_HOME}/adt-build-machine-scripts/selection**  
Scripts that prompt for selection between particular service options when there needs to be a choice made.   

**${BUILD_HOME}/adt-build-machine-scripts/templatedconfigurations**  
Scripts related to the templating system of the current build

-----------------------

Early on in the development of this toolkit I supported AWS but I decided to strip out the AWS code that I had developed because it required various additional customisation and I want to keep the "core" of the toolkit as standardised as possible. The idea here is that I don't intend to modify these core repositories with additional function but rather to simply maintain and enhance the core 'as is' based on feedback from the community and to have any further customisations done in forks of these core repos. If you want to get stuck in with your own fork that supports AWS (possibly with features like EFS as well) then you might be interested in these archived repos that have the original AWS code that I developed and which might give you some pointers on how to go about it. 

[AWS Build Machine](https://github.com/wintersys-dev/adt-build-machine-scripts-withaws)  
[AWS Autoscaler](https://github.com/wintersys-dev/adt-autoscaler-scripts-withaws)  
[AWS Webserver](https://github.com/wintersys-dev/adt-webserver-scripts-withaws)  
[AWS Database](https://github.com/wintersys-dev/adt-database-scripts-withaws)  





