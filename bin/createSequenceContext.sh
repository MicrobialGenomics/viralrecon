#!/usr/bin/env bash

#### This script will take an absolute path or a AWS:s3 pointer containing a single sequence
#### will download latest GISAID db (either pre-blast-indexed)
#### will blast the query sequence against  GISAID and extract the n(=10) top hits to contextualize
#### Will add Wuhan Reference to it and create a multi-fasta, and the resulting alignment.


fileUrl=$1
#### Check whether blastdb needs to be downloaded or created or both

#### Where the bucket is
CovidBucket="s3://covidseq-14012021-eu-west-1/"
### Files from GISAID follow a dated nomenclature. We will use it to obtain the last file
### Which is the last version and date of the GISAID Fasta DB.
GisaidFastaFile=`aws s3 ls ${CovidBucket}GISAID/DataFiles/ |awk '{print $4}' | grep fasta.gz | sort | tail -n 1`

dateString=`echo $GisaidFastaFile | sed s/sequences_// | sed s/\.fasta\.gz//`
echo "Using $GisaidFastaFile ... date is: $dateString"

GisaidFastaTmpFile="/tmp/"`basename $GisaidFastaFile`
echo "GisaidFastaTmpFile $GisaidFastaTmpFile"
GisaidBlastTmpFile="/tmp/"`basename ${GisaidFastaFile%%.gz}`
echo "GisaidBlastTmpFile $GisaidBlastTmpFile"
GisaidBlasts3File="/tmp/GisaidBlasts3Files.txt"

aws s3 ls s3://covidseq-14012021-eu-west-1/GISAID/BlastDB/ | awk '{print $4}' | grep $dateString > $GisaidBlasts3File

### Does the blast index corresponding to this file exist in /tmp?
if [ -e ${GisaidBlastTmpFile}.nal ]
    then 
    echo "Local Blast index of latest GISAID dump is found, going to use it"
### Does the blast index corresponding to this file exist in s3?
elif [  -s $GisaidBlasts3File ]
    then 
    cat $GisaidBlasts3File
    echo "Blast index for latest GISAID found in s3, downloading and using it for alignment"
    for line in `cat $GisaidBlasts3File`
        do 
            aws s3 cp ${CovidBucket}GISAID/BlastDB/$line /tmp
        done 
### If not, is the fasta file found locally? If so, we'll need to index it
elif [  -e  $GisaidFastaTmpFile  ]
then 
    echo "GISAID local file existst at $GisaidFastaTmpFile for $dateString"
    gzip -d -c $GisaidFastaTmpFile | makeblastdb -in - -dbtype nucl -out ${GisaidFastaTmpFile%%.gz} -title ${GisaidFastaTmpFile%%.gz}
    for file in ${GisaidFastaTmpFile%%.gz}.*.n*
    do 
      aws s3 cp $file ${CovidBucket}GISAID/BlastDB/ 
    done
    aws s3 cp ${GisaidFastaTmpFile%%.gz}.nal ${CovidBucket}GISAID/BlastDB/ 
### If the file is not found locally we'll need to download it as well and index it as well.
elif [[ ! -e $GisaidFastaTmpFile ]]
then 
    aws s3 cp ${CovidBucket}GISAID/DataFiles/$GisaidFastaFile /tmp 
    gzip -d -c $GisaidFastaTmpFile | makeblastdb -in - -dbtype nucl -out ${GisaidFastaTmpFile%%.gz} -title ${GisaidFastaTmpFile%%.gz}
    for file in ${GisaidFastaTmpFile%%.gz}.*.n*
    do 
      aws s3 cp $file ${CovidBucket}GISAID/BlastDB/ 
    done
    aws s3 cp ${GisaidFastaTmpFile%%.gz} ${CovidBucket}GISAID/BlastDB/ 
fi

### Either way we should have a blast index in /tmp named ${GisaidFastaTmpFile%%.gz}
### And replicated in the cloud
### Now we can start Analysis

### First we download the query sequence if it is s3 based
if [[ $fileUrl = s3:* ]]
  then  
  echo "Fasta File is s3 based, downloading"
  aws s3 cp $fileUrl /tmp 
  filename="/tmp/"`basename $fileUrl`
else 
  filename=$fileUrl
fi 

echo "Working with query sequence $filename"
seqkit stats $filename

echo "Running Blast for 10 Sequences" 
blastn -db ${GisaidFastaTmpFile%%.gz} -max_hsps 1 -num_threads 4 -max_target_seqs 10 -out ${filename%%.fasta}_blastOut10.txt -outfmt 6 -query ${filename}
cat ${filename%%.fasta}_blastOut10.txt | awk '{print $2}' > ${filename%%.fasta}_blastSeqs10.txt
seqkit grep -f ${filename%%.fasta}_blastSeqs10.txt $GisaidFastaTmpFile > ${filename%%.fasta}_blastSeqs10_$dateString.fasta
rm ${filename%%.fasta}_blastOut10.txt  ${filename%%.fasta}_blastSeqs10.txt
aws s3 cp ${filename%%.fasta}_blastSeqs10_$dateString.fasta s3://covidseq-14012021-eu-west-1/GISAID/BlastContexts/

blastn -db ${GisaidFastaTmpFile%%.gz} -max_hsps 1 -num_threads 4 -max_target_seqs 50 -out ${filename%%.fasta}_blastOut50.txt -outfmt 6 -query ${filename}
cat ${filename%%.fasta}_blastOut50.txt | awk '{print $2}' > ${filename%%.fasta}_blastSeqs50.txt
seqkit grep -f ${filename%%.fasta}_blastSeqs50.txt $GisaidFastaTmpFile > ${filename%%.fasta}_blastSeqs50_$dateString.fasta
rm ${filename%%.fasta}_blastOut50.txt  ${filename%%.fasta}_blastSeqs50.txt
aws s3 cp ${filename%%.fasta}_blastSeqs50_$dateString.fasta s3://covidseq-14012021-eu-west-1/GISAID/BlastContexts/