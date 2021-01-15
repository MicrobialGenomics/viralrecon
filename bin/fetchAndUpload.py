#!/usr/bin/env python

### 2021-01-14 19:39:07 MNJ Will fetch fastq files from BaseSpace Project using Basespace reference and default credentials
### Will use BAseSpace python SDK.
### Look at https://github.com/Teichlab/basespace_fq_downloader

### Will then upload files to s3 using bucket specified as parameter with directory name
### AWS:s3 credentials will use either IAM or .aws/credentials file.
### Will (optionally) populate database with information about fastq files and Project run