#!/bin/bash


prefix=$1
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "MYDIR is $MYDIR"

### Obtain s3Dir from prefix
projectName=`basename $prefix`
s3pattern=`echo $projectName | sed s/_.*//`

s3Dir=`aws s3 ls s3://covidseq-14012021-eu-west-1/Runs/ | grep $s3pattern | awk '{print $2}'`
for file in `ls ${prefix}*gisaid.csv`
do
	echo "Processing $file and ${file%%.csv}.fasta"
	echo "Logging to ${file%%.csv}Upload.txt"
	echo "gisaid_uploader -a $MYDIR/gisaid_uploader.authtoken CoV upload --fasta ${file%%.csv}.fasta --csv $file > ${file%%.csv}Upload.txt"
	gisaid_uploader -a $MYDIR/gisaid_uploader.authtoken CoV upload --fasta ${file%%.csv}.fasta --csv $file > ${file%%.csv}Upload.txt
	echo "aws s3 cp ${file%%.csv}Upload.txt ${s3Bucket}Runs/$s3Dir"
	aws s3 cp ${file%%.csv}Upload.txt ${s3Bucket}Runs/$s3Dir

done
