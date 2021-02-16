#!/bin/bash

### Will extract submission files that are valid for gisaid
### and perform data submission using specific tokens. 



gisaidFastaFile=$1 
gisaidMetadataFile=$2



gisaid_uploader -t ./gisaid_uploader.authtoken -l /tmp/log.json CoV upload --fasta $gisaidFastaFile --csv $gisaidMetadataFile  
