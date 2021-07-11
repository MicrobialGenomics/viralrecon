#!/bin/bash

### Wrapper script for automatized execution
### 2021-06-30 12:43:01 MNJ

LOCKDIR=/tmp/runWrapperLock.lck

if mkdir $LOCKDIR
then
    # Do important, exclusive stuff
    MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    echo "MYDIR is $MYDIR"
    . $MYDIR/environment.sh
    ### This will add pending runs to /tmp/covid_projects_pending.txt
    ~/miniconda3/bin/python3 $MYDIR/SQS_messages.py
    ### This will try to run pending projects if Illumina/basespace data is available
    for run in `cat /tmp/covid_projects_pending.txt | awk 'BEGIN{FS=","}{print $1}'`
    do
      myLog=~/logs/viralrecon_"$(date +"%Y_%m_%d_%I_%M_%p").log"
      . $MYDIR/fetchAndUpload.sh $run | tee > $myLog
    done
  if rmdir $LOCKDIR
    then
        echo "Victory is mine"
        echo "Releasing Lock"
    else
        echo "Could not remove lock dir" >&2
  fi
else
    # Handle error condition
    echo "Another instance of this script is already running"
fi


