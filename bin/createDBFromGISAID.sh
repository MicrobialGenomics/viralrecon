#!/bin/bash

### This script will use GISAID data to create meaningful table through GISAID
### NextClade and Pangolin Analysis

### RAw Sequence and Metadata will be stored and updated periodically in s3 location
### Nomenclature still to be defined

CovidBucket="s3://***REMOVED***/"
aws s3 rm s3://***REMOVED***/GISAID/DataFiles/AnalyzedFiles.txt 
rm /tmp/AnalyzedFiles.txt
aws s3 cp s3://***REMOVED***/GISAID/DataFiles/AnalyzedFiles.txt /tmp

### Files from GISAID follow a dated nomenclature. We will use it to obtain the last file
GisaidFastaFile=`aws s3 ls ${CovidBucket}GISAID/DataFiles/ |awk '{print $4}' | grep fasta.gz | sort | tail -n 1`
GisaidMetadataFile=`aws s3 ls ${CovidBucket}GISAID/DataFiles/ |awk '{print $4}' | grep metadata_ | sort | tail -n 1`

### Define Origin filed for data in production environment
GISAIDDataFilesDir="GISAID/DataFiles/"
GisaidFastaFile=${CovidBucket}${GISAIDDataFilesDir}$GisaidFastaFile
GisaidMetadataFile=${CovidBucket}${GISAIDDataFilesDir}$GisaidMetadataFile

echo "Using GISAID Fasta File: $GisaidFastaFile"
echo "  and GISAID Metadata File: $GisaidMetadataFile"

if (grep -F $GisaidFastaFile /tmp/AnalyzedFiles.txt)
then  
   echo "$GisaidFastaFile has already been analyzed"
   return 
fi 

if (grep -F $GisaidMetadataFile /tmp/AnalyzedFiles.txt)
then 
  echo  "$GisaidMetadataFile has already been analyzed"
  return
fi

echo "There are new data files from GISAID in the bucket, downloading them"
aws s3 cp $GisaidFastaFile /tmp
aws s3 cp $GisaidMetadataFile /tmp


echo $GisaidFastaFile >> /tmp/AnalyzedFiles.txt
echo $GisaidMetadataFile >> /tmp/AnalyzedFiles.txt



### Redefined files for local analysis
GisaidFastaFile="/tmp/"`basename $GisaidFastaFile`
GisaidMetadataFile="/tmp/"`basename $GisaidMetadataFile`

### Defined Origin files for testing
#GisaidFastaFile="/Users/mnoguera/Downloads/sequences_2021-02-04_09-27.fasta.gz"
#GisaidMetadataFile="/Users/mnoguera/Downloads/metadata_2021-02-04_20-48.tsv.gz"


### Define locations of local temporary work fils
CatMetadataFile="/tmp/CatMetadata.tsv"
CatIDsFile="/tmp/CatIDs.txt"
CatFastaFile="/tmp/CatFasta.fasta"

### Keep Catalan metadata and fasta sequences
gzcat ${GisaidMetadataFile} | head -n 1 > $CatMetadataFile
gzcat ${GisaidMetadataFile} | fgrep Europe | fgrep Spain >> $CatMetadataFile
gzcat ${GisaidMetadataFile} | fgrep Europe | fgrep Spain  | awk '{print $1}' > $CatIDsFile
seqkit grep -f $CatIDsFile $GisaidFastaFile > $CatFastaFile
### Use Metadata File to keep al Sequences From Catalunya, along with their collection dates, Originating and Submitting Labs and parse_seqids

# We could further filter sequences/metadata comparing with DB contents and keeping only "new" sequences and
# This would increase speed

### To run Nextclade to call mutations on sequences and signature mutation-based phylotyping
docker run -it --rm -u 1000 --volume="/tmp/:/seq" \
neherlab/nextclade nextclade --jobs 4 --input-fasta '/seq/CatFasta.fasta' \
--output-csv='/seq/NextCladeSequences_output.csv'

### To run Pangolin for phylogenetic classification
docker run -it --rm --volume="/tmp/:/seq" \
microbialgenomics/pangolin pangolin '/seq/CatFasta.fasta' -t 4 --outfile '/seq/lineage_report.csv'

cp /tmp/lineage_report.csv  /tmp/Pangolin_output.csv

### Now we have metadata and analysis results from NextClade and Pangolin

### Insert this information into specific DB
### By now a csv fil

aws s3 cp /tmp/AnalyzedFiles.txt ${CovidBucket}${GISAIDDataFilesDir}
