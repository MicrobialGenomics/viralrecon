#!/usr/bin/bash

### 2021-01-14 19:39:07 MNJ Will fetch fastq files from BaseSpace Project using Basespace reference and default credentials
### Will use BS CLI from https://developer.basespace.illumina.com/docs/content/documentation/cli/cli-overview

### Other SDK for basespace that may prove useful for the same purpose.
### Look at https://github.com/Teichlab/basespace_fq_downloader
### Check also https://github.com/nh13/basespace-invaders
s3Bucket="s3://covidseq-14012021-eu-west-1/"

### BS-CLI download for a project using
### By combining these download can be done automatically 
### Need to first how authentication token is managed by

### Let's ensure that bs client is there.
#To download  CLI app
if [[ ! -e $HOME/bin/bs ]]
then
echo "Downloading BaseSpace CLI client"
wget "https://api.bintray.com/content/basespace/BaseSpaceCLI-EarlyAccess-BIN/latest/\$latest/amd64-osx/bs?bt_package=latest" -O $HOME/bin/bs
fi

### Authentication toke must be acquired manually and can be injected afterwards
### Token is stored in $HOME/.basespace/default.cfg
### If not the following command can be used to renew the token. Not about sure expiry dates
# bs auth  

# ### Downloads all files from project by id
# bs download project -n 218466248 -o /tmp
# ### Downloads all files (Fastq.gz) from project by is
# bs download project -i <ProjectID> -o <output> --extension=fastq.gz



### Usually We'll have a passed argument containing a reference to a project
name=$1 || echo "Project name not defined" 
csvFile=$2 || echo "Metadata file not defined, will process all samples"
### Lists all projects to csv file, filtering by name
### redirect output to a filecan be useful to get project id
bs list projects --filter-term=$name -f csv > /tmp/${name}_project.csv
### Obtain the project BaseSpace ID
projectID=`cat /tmp/${name}_project.csv | grep "${name}," | awk 'BEGIN{FS=","}{print $2}'`
### Create a unique string for this run
projectString=${name}_${projectID}_`date +"%Y-%m-%d"`
s3Location=${s3Bucket}Runs/${projectString}/

echo "Downloading all files for project $projectID or $name"
### lists all samples within bioproject
bs list biosamples --project-id=$projectID -f csv > /tmp/${name}_samples.csv
mkdir /tmp/$projectString
bs download project -i $projectID -o /tmp/$projectString --overwrite


### Will then upload files to s3 using bucket specified as parameter with directory name
### AWS:s3 credentials will use either IAM or .aws/credentials file.
### Will (optionally) populate database with information about fastq files and Project run
echo "Trying to copy data to ${s3Location}RawData"
echo "sample,fastq_1,fastq_2" > /tmp/${name}_NFSamples.csv

for file in `find /tmp/$projectString -name *fastq.gz | grep _R1_`
do
 fileR1=$file 
 fileR2=`echo $fileR1 | sed s/_R1_/_R2_/`
 ### Add extra filtering steps (is sample in the csv file)
 ### What's the sample LibId (keep it)
 echo "copying $file to ${s3Location}RawData"
 filename=${file##*/}
 filenameR1=$filename
 filenameR2=`echo $filenameR1 | sed s/_R1_/_R2_/`
 samplename=${filename%%_S\d*}
 echo $samplename,${s3Location}RawData/${filenameR1},${s3Location}RawData/${filenameR1} | tee >> /tmp/${name}_NFSamples.csv
 echo $filename $samplename
 aws s3 cp $file ${s3Location}RawData
 ### Keep Locations of files
done
aws s3 cp  /tmp/${name}_samples.csv ${s3Location}RawData
aws s3 cp /tmp/${name}_project.csv ${s3Location}RawData
aws s3 cp /tmp/${name}_NFSamples.csv ${s3Location}RawData

echo "Cleaning up"
rm -rf /tmp/$projectString /tmp/${name}_samples.csv  /tmp/${name}_project.csv 


### Can we run nextflow pipeline from here?
/tmp/${name}_NFSamples.csv  ### This file could be fed into nextflow

