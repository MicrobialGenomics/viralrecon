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
s3Bucket="s3://***REMOVED***/"

NFSamplesFile=$1
NFOutDir=$2

#### Need to source a file with credentials an
#### AWS credentials are IAM managed
#### NextFlow credentials 
cd /tmp/

git clone https://github.com/MicrobialGenomics/viralrecon.git
export TOWER_ACCESS_TOKEN=4b252dc4118da98eaaacebd6e07aa6670f000934
export NXF_VER=20.10.0 

### Try with modified version of viralrecon/Full Dataset
### s3:///microbialgenomics-scratch is for temporary files, will keep files for 15 day time
### All config files for analysis are on s3://***REMOVED***/NextFlow/Configs/
nextflow run /Users/mnoguera/Documents/Work/Development/viralrecon/main.nf --input $NFSamplesFile  \
 --fasta /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.fasta \
 --gff /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.gff3 \
  -profile awsbatch --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
 --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 \
  -bucket-dir 's3://microbialgenomics-scratch/' \
  -w 's3://microbialgenomics-scratch/' \
  --outdir ${NFOutDir}results --with-tower \
  --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 --callers ivar 


#   ### To run nextflow locally for testing
# nextflow run /Users/mnoguera/Documents/Work/Development/viralrecon/main.nf --input $NFSamplesFile  \
#  --fasta /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.fasta \
#  --gff /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.gff3 \
#   -profile docker --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
#   -w /tmp/workdir --outdir /tmp/results\
#   --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 

#   nextflow run /tmp/viralrecon-dev/main.nf --input $NFSamplesFile  \
#  --fasta /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.fasta \
#  --gff /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.gff3 \
#   -profile docker --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
#   -w /tmp/workdir --outdir /tmp/results\
#   --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 
# ### To run Nextclade to call mutations on sequences
# docker run -it --rm -u 1000 --volume="/Users/mnoguera/Downloads/:/seq" \
# neherlab/nextclade nextclade --input-fasta '/seq/gisaid_hcov-19_2021_01_25_16.fasta' \
# --output-csv='/seq/nextclade_output.csv'