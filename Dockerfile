FROM nfcore/viralrecon:1.1.0

# Updating environment with yml
RUN conda env update -f environment.yml -y 