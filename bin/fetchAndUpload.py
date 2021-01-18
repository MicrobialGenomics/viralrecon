#!/usr/bin/env python

### 2021-01-14 19:39:07 MNJ Will fetch fastq files from BaseSpace Project using Basespace reference and default credentials
### Will use BAseSpace python SDK.
### Look at https://github.com/Teichlab/basespace_fq_downloader
### Check also https://github.com/nh13/basespace-invaders
### Check also https://developer.basespace.illumina.com/docs/content/documentation/cli/cli-overviewç

### BS-CLI download for a project using
### By combining these download can be done automatically 
### Need to first how authentication token is managed by

#To download  CLI app
wget "https://api.bintray.com/content/basespace/BaseSpaceCLI-EarlyAccess-BIN/latest/\$latest/amd64-osx/bs?bt_package=latest" -O $HOME/bin/bs
#to obtain authentication token
#authentication tokens are managed through .basespace/ dir
bs auth 

### Downloads all files from project by id
bs download project -i 218466248 -o /tmp
### Downloads all files (Fastq.gz) from project by is
bs download project -i <ProjectID> -o <output> --extension=fastq.gz
### Lists all projects to csv file, can be useful to get project id
bs list projects --filter-term='IrsiCaixa_Covid' -f csv
### lists all samples within bioproject
bs list biosamples --project-id=208813606 -f csv
### Download fastqfiles from biosampls
bs download biosample -i 339152845 -o /tmp --extension="fastq.gz" --overwrite


### Will then upload files to s3 using bucket specified as parameter with directory name
### AWS:s3 credentials will use either IAM or .aws/credentials file.
### Will (optionally) populate database with information about fastq files and Project run