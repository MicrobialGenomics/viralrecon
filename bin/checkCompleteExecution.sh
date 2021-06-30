#!/bin/bash
### Goal is tov erify that a Covid Run has finished successfully and the results have been obtained and are in s3.
s3Location=$1
projectString=`basename $s3Location`
projectName=`echo $projectString | awk 'BEGIN {FS="_"}{print $2}'`

echo "Checking execution success for $projectName and $projectString" 
echo "Using AWS/s3 Location: $s3Location"
echo "Using Project String: $projectString"
echo "Project Name is: $projectName"
not_exist=false
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/$projectName.csv || not_exist=true
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/NFResults.csv || not_exist=true
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/Pangolin_output.csv || not_exist=true
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/NextCladeSequences_output.csv || not_exist=true
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/${projectName}_Microbiologia_HUGTiP.xlsx || not_exist=true
aws s3api head-object --bucket covidseq-14012021-eu-west-1 --key Runs/$projectString/${projectName}_Microbiologia_HUGTiP.fasta || not_exist=true

if $not_exist ; then 
    echo "Project did not run well, apparently"
else
    echo "Project did run well, pending->success"
    grep -v $projectName /tmp/covid_projects_pending.txt > /tmp/kk
    mv kk /tmp/covid_projects_pending.txt
    echo $projectName,success >> /tmp/covid_projects_success.txt
fi