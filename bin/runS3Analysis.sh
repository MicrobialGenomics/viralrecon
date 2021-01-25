#!/usr/bin/bash

### 2021-01-15 08:30:08 MNJ 
### Will either:
# - Take a txt file with the samples file used by viralrecon (with names and fastq locations) to run the nextflow pipeline
# - Scan s3 bucket for fastq, check if they are analyzed, if not select those that have not been analyzed.

### After Analysis DB needs to be updated with the analysis info (to be defined) and files for GISAID/ENA upload need to be created

### Where to locate control layer with the no-repeat analysis
### nextflow manages this based on scratch dir contents, but these are remove in 15 days.

### - opts s3 Dir or single file (auto-detect)
###    --> Need to generate samples.txt file from s3Dir content

### - file with s3 routes
###    --
s3Bucket="s3://covidseq-14012021-eu-west-1/"

NFSamplesFile=$1
NFOutDir=$2

cd /tmp/

git clone https://github.com/MicrobialGenomics/viralrecon.git


### Try with modified version of viralrecon/Full Dataset
### s3:///microbialgenomics-scratch is for temporary files, will keep files for 15 day time
### All config files for analysis are on s3://covidseq-14012021-eu-west-1/NextFlow/Configs/
nextflow run /Users/mnoguera/Documents/Work/Development/viralrecon/main.nf --input $NFSamplesFile  \
 --fasta /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.fasta \
 --gff /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.gff3 \
  -profile awsbatch --skip_assembly \
 --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 \
  -bucket-dir 's3://microbialgenomics-scratch/' \
  -w 's3://microbialgenomics-scratch/' \
 --outdir ${NFOutDir}results --with-tower \
 --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20

### Manual Inspection of results

### Contamination?
### Coverage?
### Number of reads(raw/filtered/aligned) 
### Use kraken2 output to report contamination?

### Scan results files to keep selected variables
### Download to local

aws s3 cp --recursive ${NFOutDir}results /tmp/results
