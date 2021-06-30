#!/bin/bash

### Wrapper script for automatized execution
### 2021-06-30 12:43:01 MNJ
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "MYDIR is $MYDIR"
. $MYDIR/environment.sh

### This will add pending runs to /tmp/covid_projects_pending.txt
~/miniconda3/bin/python3 $MYDIR/SQS_messages.py

### This will try to run pending projects if Illumina/basespace data is available
for run in `cat /tmp/covid_projects_pending.txt | awk 'BEGIN{FS=","}{print $1}'`
do
    . $MYDIR/fetchAndUpload.sh $run
done