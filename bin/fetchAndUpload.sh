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

### Let's ensure that bs client is therpwde.
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
samplesFile=$2 || echo "Metadata file not defined, will process all samples"
idCrossFile=$3 || echo "No ID CorssFile passed as argument, filenames will need to match library_id"


### Behaviour: If Id cross File is not provided $name variable will be used throughout and needs to correspond to the basespace project
### Otherwise: $name variable will only be used to retrieve samples, but $newProjectName will be used for further labeling
if [ ! -z ${idCrossFile+x } ] ### If variable is set
then  
newProjectName=`grep $name $idCrossFile | awk '{print $2}'`
else ##
newProjectName=$name
fi

### Lists all projects to csv file, filtering by name
### redirect output to a filecan be useful to get project id
bs list projects --filter-term=$name -f csv > /tmp/${newProjectName}_project.csv
### Obtain the project BaseSpace ID
projectID=`cat /tmp/${newProjectName}_project.csv | grep "${name}," | awk 'BEGIN{FS=","}{print $2}'`
### Create a unique string for this run


projectString=`date +"%Y-%m-%d"`_${newProjectName}_${projectID}
s3Location=${s3Bucket}Runs/${projectString}/

echo "Downloading all files for project $projectID or $name renamed(or not) as $newProjectName"
### lists all samples within bioproject
bs list biosamples --project-id=$projectID -f csv > /tmp/${newProjectName}_samples.csv
mkdir /tmp/$projectString
bs download project -i $projectID -o /tmp/$projectString --overwrite

if [ ! -z ${idCrossFile+x} ] ### If variable is set we'll need to rename all fastq files that have been downloaded.
then  
    for file in `find /tmp/$projectString -name *fastq.gz`
    do
        echo "processing $file for samplename crossing"
        filename=${file##*/}
        filedir=`dirname $file`
        samplename=${filename%%_S*}
        newSampleName=`fgrep $samplename $idCrossFile | awk '{print $2}'`
        newFileName=`echo $filename | sed s/$samplename/$newSampleName/`
        echo "New file is $newFile, moving from $file"
        mv $file ${filedir}/${newFileName}
    done
fi
echo "Finished renaming or not"
break
### Will then upload files to s3 using bucket specified as parameter with directory name
### AWS:s3 credentials will use either IAM or .aws/credentials file.
### Will (optionally) populate database with information about fastq files and Project run
echo "Trying to copy data to ${s3Location}RawData"
echo "sample,fastq_1,fastq_2" > /tmp/${newProjectName}_NFSamples.csv

for file in `find /tmp/$projectString -name *fastq.gz | grep _R1_`
do
 fileR1=$file 
 fileR2=`echo $fileR1 | sed s/_R1_/_R2_/`
 ### Add extra filtering steps (is sample in the csv file?)
 ### What's the sample LibId (keep it)
 
 
 filename=${file##*/}
 filenameR1=$filename
 
 filenameR2=`echo $filenameR1 | sed s/_R1_/_R2_/`
 samplename=${filename%%_S*}
 if  ! grep -F "$samplename" $samplesFile
then
### We won't analyze samples that are not passed as argument.
    echo "Sample $samplename not found in $samplesFile ... Skipping"
    continue
fi
echo "copying $file to ${s3Location}RawData"
 echo $samplename,${s3Location}RawData/${filenameR1},${s3Location}RawData/${filenameR2} | tee >> /tmp/${newProjectName}_NFSamples.csv
 echo $filename $samplename
 aws s3 cp $fileR1 ${s3Location}RawData/
 aws s3 cp $fileR2 ${s3Location}RawData/
 ### Keep Locations of files
done
aws s3 cp  /tmp/${name}_samples.csv ${s3Location}RawData/
aws s3 cp /tmp/${name}_project.csv ${s3Location}RawData/
aws s3 cp /tmp/${name}_NFSamples.csv ${s3Location}RawData/

echo "Cleaning up"
rm -rf /tmp/$projectString /tmp/${newProjectName}_samples.csv  /tmp/${newProjectName}_project.csv 


### Can we run nextflow pipeline from here?
/tmp/${newProjectName}_NFSamples.csv  ### This file could be fed into nextflow
echo $s3Location
