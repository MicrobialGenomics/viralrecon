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
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
### s3Bucket should be defined in bin/environment.sh
# s3Bucket="s3://bucketName/"
. ${MYDIR}/environment.sh
echo "Using bucket $s3Bucket"


NFSamplesFile=$1
NFOutDir=$2

RunName=`basename $NFSamplesFile`
RunName=${RunName%%_NFSamples.csv}
randString=` openssl  rand -hex 2`
RunName=${RunName}_$randString
#### Need to source a file with credentials an
#### AWS credentials are IAM managed
#### NextFlow credentials 
cd /tmp/

git clone https://github.com/MicrobialGenomics/viralrecon.git
export TOWER_ACCESS_TOKEN=4b252dc4118da98eaaacebd6e07aa6670f000934
export NXF_VER=20.10.0 

echo "Running pipeline from $COVIDSEQPIPELINEDIR"
echo "With name $RunName"
### Try with modified version of viralrecon/Full Dataset
### s3:///microbialgenomics-scratch is for temporary files, will keep files for 15 day time
### All config files for analysis are on s3://covidseq-14012021-eu-west-1/NextFlow/Configs/
### For some reason outputting of trace on s3 support is broken. Local tracedir is chosen and then uploaded.

# if [[ $RunProfile == "awsbatch" ]]
# then
#   echo "Running on AWS/Batch"
#   nextflow run ${COVIDSEQPIPELINEDIR}main.nf --input $NFSamplesFile \
#     --fasta $ReferenceDir/NC_045512.2.fasta \
#     --gff $ReferenceDir/NC_045512.2.gff3 \
#       -profile awsbatch --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
#     --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 \
#     -bucket-dir 's3://microbialgenomics-scratch/' \
#     -w 's3://microbialgenomics-scratch/' -name ${RunName} --skip_picard_metrics \
#     --outdir ${NFOutDir}results --tracedir /tmp/tracedir \
#     --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 --align_unpaired --callers ivar \
#     -with-report /tmp/${NFSamplesFile%%_NFSamples.csv}_NFReport.html \
#     -with-timeline /tmp/${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html --skip_multiqc
#   aws s3 cp ${NFSamplesFile%%_NFSamples.csv}_NFReport.html ${NFOutDir}results/
#   aws s3 cp ${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html ${NFOutDir}results/
# elif [[ $RunProfile == "docker" ]]
# then
#   echo "Running Locally on docker"
#   nextflow run ${COVIDSEQPIPELINEDIR}main.nf --input $NFSamplesFile \
#     --fasta $ReferenceDir/NC_045512.2.fasta \
#     --gff $ReferenceDir/NC_045512.2.gff3 \
#     -profile docker --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
#     -bucket-dir 's3://microbialgenomics-scratch/' \
#     -w 's3://microbialgenomics-scratch/' -name ${RunName} --skip_picard_metrics \
#     --outdir ${NFOutDir}results --tracedir /tmp/tracedir \
#     --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 --align_unpaired --callers ivar \
#     -with-report /tmp/${NFSamplesFile%%_NFSamples.csv}_NFReport.html \
#     -with-timeline /tmp/${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html --skip_multiqc
# fi

### amplicon based strategy
if [[ $RunProfile == "awsbatch" ]]
then
  echo "Running on AWS/Batch"
  nextflow run ${COVIDSEQPIPELINEDIR}main.nf --input $NFSamplesFile \
    --fasta $ReferenceDir/NC_045512.2.fasta \
    --gff $ReferenceDir/NC_045512.2.gff3 \
      -profile awsbatch --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
    --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 \
    --amplicon_bed $ReferenceDir/../ArticPrimers_BediVar.bed --protocol amplicon \
    -bucket-dir 's3://microbialgenomics-scratch/' \
    -w 's3://microbialgenomics-scratch/' -name ${RunName} --skip_picard_metrics \
    --outdir ${NFOutDir}results --tracedir /tmp/tracedir \
    --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 --align_unpaired --callers ivar \
    -with-report ${NFSamplesFile%%_NFSamples.csv}_NFReport.html \
    -with-timeline ${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html --skip_multiqc
  aws s3 cp ${NFSamplesFile%%_NFSamples.csv}_NFReport.html ${NFOutDir}results/
  aws s3 cp ${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html ${NFOutDir}results/
elif [[ $RunProfile == "docker" ]]
then
  echo "Running Locally on docker"
  nextflow run ${COVIDSEQPIPELINEDIR}main.nf --input $NFSamplesFile \
    --fasta $ReferenceDir/NC_045512.2.fasta \
    --gff $ReferenceDir/NC_045512.2.gff3 \
    -profile docker --skip_assembly --min_mapped_reads 1000 --email mnoguera@irsicaixa.es \
    -bucket-dir 's3://microbialgenomics-scratch/' \
    -w 's3://microbialgenomics-scratch/' -name ${RunName} --skip_picard_metrics \
    --amplicon_bed $ReferenceDir/../ArticPrimers_BediVar.bed --protocol amplicon \
    --outdir ${NFOutDir}results --tracedir /tmp/tracedir \
    --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20 --align_unpaired --callers ivar \
    -with-report /tmp/${NFSamplesFile%%_NFSamples.csv}_NFReport.html \
    -with-timeline /tmp/${NFSamplesFile%%_NFSamples.csv}_NFtimeline.html --skip_multiqc
fi





# ### To run Nextclade to call mutations on sequences
# docker run -it --rm -u 1000 --volume="/Users/mnoguera/Downloads/:/seq" \
# neherlab/nextclade nextclade --input-fasta '/seq/gisaid_hcov-19_2021_01_25_16.fasta' \
# --output-csv='/seq/nextclade_output.csv'
