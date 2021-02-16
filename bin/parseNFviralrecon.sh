#!/usr/bin/bash

NFSamplesFile=$1
NFOutDir=$2

### Manual Inspection of results

### (MNJ 2021-01-25 10:16:37 By now, this is a bash script and generate csv, in time should be transferred to python when interacting with DB.)

### Note that when running on cloud, results dir needs to be on s3
### Need to download it and select results to import into DB or csv?
aws s3 cp --recursive ${NFOutDir}results /tmp/results


### Variables to extractin, in csv Format.
# FlowCellID	
# InstrumentID	
# s3FastqR1
# s3FastqR2	
# s3BamFile	
# s3CovFile	
# RawDataSeqs	
# COVIDSeqs	
# FastaSequence	
# PercCoverage	
# MedianCoverage	
# QPassBool	


### BCFTools section ---> Will use output from BCF tools
### s3FastqR1, and s3FastqR2 from NFSamplesFile
### s3BamFile results/variants/bam/*.mkD.sorted.bam || contains unmapped reads
### s3CovFile samtools depth results/variants/bam/*.mkD.sorted.bam
### RawDataSeqs samtools view results/variants/bam/*.mkD.sorted.bam | wc -l
### COVIDSeqs samtools vied-F 4 results/variants/bam/*.mkD.sorted.bam | wc -l
### s3FastaFile results/variants/bcftools/consensus/*masked*fa 
### results/variants/bcftools/consensus/*masked*fa    --> consensus sequence, No degenerate positions
### results/variants/bcftools/consensus/base_qc/*base_counts.tsv   --> Sequence composition  || percN=`tail -n 1 $file | awk '{print $3}'` || PercCoverage=100-percN
# base    freq    percI
# A   5492    18.3863408101774
# C   3447    11.5400066956813
# T   5788    19.3773016404419
# G   3728    12.480749916304
# N   11415   38.2156009373954
### results/variants/bam/picard_metrics/*coverage_metrics  --> coverage
# samtools  depth results/variants/bam/*.mkD.sorted.bam | awk '{sum+=$3} END { print "Average = ",sum/NR}' > ${sample}_depthOfCoverage.txt

rm /tmp/NFResults.csv
rm /tmp/NextCladeSequences.fasta
echo "library_id,InstrumentID,FlowcellID,s3FastqR1,s3FastqR2,s3BamFile,s3CovFile,RawDataSeqs,CovidSeqs,FastqSequence,PercCov,DepthOfCov,s3FastaFile" > /tmp/NFResults.csv
for line in `cat $NFSamplesFile | tail -n +2`
do
   # echo $line
   sampleName=`echo $line | awk 'BEGIN{FS=","}{print $1}'`
   instrumentID=`samtools view /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam | head -n 1 | awk '{print $1}' | awk 'BEGIN{FS=":"}{print $1}'`
   flowcellID=`samtools view /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam | head -n 1 | awk '{print $1}' | awk 'BEGIN{FS=":"}{print $3}'`

  # echo "sampleName is $sampleName"
    s3FastqR1=`echo $line | awk 'BEGIN{FS=","}{print $2}'`
    s3FastqR2=`echo $line | awk 'BEGIN{FS=","}{print $3}'`
   # echo "s3 Files are $s3FastqR1 and $s3FastqR2"
    s3BamFile=${NFOutDir}results/variants/bam/${sampleName}.mkD.sorted.bam
   # echo "s3 Bam File is $s3BamFile"
    s3FastaFile=${NFOutDir}results/variants/bcftools/consensus/${sampleName}.consensus.masked.fa
    cat /tmp/results/variants/bcftools/consensus/${sampleName}.consensus.masked.fa  >> /tmp/NextCladeSequences.fasta
  #  echo "s3 consensus File is $s3FastaFile"
    samtools depth /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam > /tmp/results/variants/bam/${sampleName}.mkD.sorted.cov.tsv
    aws s3 cp /tmp/results/variants/bam/${sampleName}.mkD.sorted.cov.tsv ${NFOutDir}results/variants/bam/
    s3CovFile=${NFOutDir}results/variants/bam/${sampleName}.mkD.sorted.cov.tsv
   # echo "s3 Coverage file is $s3CovFile"
    RawDataSeqs=`samtools view /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam | wc -l`
   # echo "File has $RawDataSeqs raw sequences"
    CovidSeqs=`samtools view -F 4 /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam | wc -l`
   # echo "File has $CovidSeqs covid sequences"
    ConsensusSequence=`tail -n +2 /tmp/results/variants/bcftools/consensus/${sampleName}.consensus.masked.fa | tr -d '\n'`
    DepthOfCoverage=`samtools  depth /tmp/results/variants/bam/${sampleName}.mkD.sorted.bam | awk '{sum+=$3} END { print sum/NR}'`
    PercN=`tail -n 1 /tmp/results/variants/bcftools/consensus/base_qc/${sampleName}.base_counts.tsv | awk '{print $3}'`
    #echo "$PercN of genome is N"
    PercCov=`echo "(100-$PercN)" | bc -l`
   # echo "$PercCov of genome is covered"
    echo "${sampleName},${instrumentID},${flowcellID},${s3FastqR1},${s3FastqR2},${s3BamFile},${s3CovFile},${RawDataSeqs},${CovidSeqs},${ConsensusSequence},${PercCov},${DepthOfCoverage},${s3FastaFile}," >> /tmp/NFResults.csv
done

aws s3 cp /tmp/NFResults.csv ${NFOutDir}


### To run Nextclade to call mutations on sequences and signature mutation-based phylotyping
docker run -it --rm -u 1000 --volume="/tmp/:/seq" \
neherlab/nextclade nextclade --input-fasta '/seq/NextCladeSequences.fasta' \
--output-csv='/seq/NextCladeSequences_output.csv'

aws s3 cp /tmp/NextCladeSequences_output.csv ${NFOutDir}


### To run Pangolin for phylogenetic classification
docker run -it --rm --volume="/tmp/:/seq" \
microbialgenomics/pangolin pangolin -o '/seq/lineage_report.csv' '/seq/NextCladeSequences.fasta' 

cp /tmp/lineage_report.csv /tmp/Pangolin_output.csv
aws s3 cp /tmp/Pangolin_output.csv ${NFOutDir}


### Ivar
### results/variants/consensus/*masked*fa    --> consensus sequence
### results/variants/consensus/base_qc/*base_counts.tsv   --> Sequence composition 
### results/variants/bam/picard_metrics/*coverage_metrics  --> coverage
### results/    --> bedfile
### No Results for insufficient coverage

### varscan2

### Custom
### results/    --> consensus sequence
### results/    --> Sequence composition
### results/    --> coverage
### results/    --> bedfile




### Contamination?
### Coverage?
### Number of reads(raw/filtered/aligned) 
### Use kraken2 output to report contamination?

### Scan results files to keep selected variables
### Download to local


