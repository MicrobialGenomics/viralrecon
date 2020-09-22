FROM nfcore/viralrecon:1.1.0

# Installing Trimmomatic
RUN conda install -c bioconda Trimmomatic

# Installing pysam
RUN pip install pysam && pip3 install pysam