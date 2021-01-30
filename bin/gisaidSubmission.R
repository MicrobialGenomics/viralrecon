### GISAID Uploader
args = commandArgs(trailingOnly=TRUE)

if(is.na(args[1])){
  print("You need to specify a result file containing data neede by gisaid in the specified coding")
  print("Metadata file needs to include library_id, at least")
}

ResultsFile=args[1] 
# ResultsFile="~/Downloads/Covid-P001_Microbiologia_HUGTiP.csv"
GisaidSubmitRoot=gsub(".csv","",ResultsFile)
GisaidSubmitFasta=paste(GisaidSubmitRoot,"_gisaid.fasta",sep="")
GisaidFastaFilename=basename(GisaidSubmitFasta)
GisaidSubmitCsv=paste(GisaidSubmitRoot,"_gisaid.csv",sep="")

outputDF <- data.frame(matrix(ncol = 29, nrow = 0))
y<-c("submitter","fn","covv_virus_name","covv_type","covv_passage","covv_collection_date",
"covv_location","covv_add_location","covv_host","covv_add_host_info","covv_gender",
"covv_patient_age","covv_patient_status","covv_specimen","covv_outbreak","covv_last_vaccinated",
"covv_treatment","covv_seq_technology","covv_assembly_method","covv_coverage","covv_orig_lab","covv_orig_lab_addr",
"covv_provider_sample_id","covv_subm_lab","covv_subm_lab_addr","covv_subm_sample_id","covv_authors","covv_comment","comment_type")


x <- c("Submitter", "FASTA filename", "Virus name","Type",
       "Passage details/history","Collection date","Location",
       "Additional location information","Host","Additional host information",
       "Gender","Patient age","Patient status","Specimen source",
       "Outbreak","Last vaccinated","Treatment","Sequencing technology",
       "Assembly method","Coverage","Originating lab","Address",
       "Sample ID given by the sample provider","Submitting lab",
       "Address","Sample ID given by the submitting laboratory",
       "Authors","","")
colnames(outputDF) <- y
# outputDF[1,]<-x

gisaidType<-"betacoronavirus"
gisaidSubmitter<-"mnoguera"
gisaidSequencingTechnology<-"Illumina/MiSeq"
gisaidAssemblyMethod<-"Viralrecon/bcftools"
gisaidLocalAuthors<-paste("Marc Noguera-Julian","Mariona Parera","Maria Casadellà", "Pilar Armengol", "Francesc Catala-Moll",sep=", ")
gisaidLocalAuthors<-iconv(gisaidLocalAuthors,from="UTF-8",to="UTF-8")
gisaidSubmittingLab<-"IrsiCaixa - Can Ruti CovidSeq"
gisaidSubmittingLabAddress<-"Fundació irsiCaixa. Hospital Universitari Germans Trias i Pujol(HUGTiP), 2a planta, maternal Ctra Canyet s/n, Badalona"
gisaidLocalAuthors<-iconv(gisaidSubmittingLabAddress,from="UTF-8",to="UTF-8")

DF<-read.csv(ResultsFile,fileEncoding = "UTF-8",sep=";")
  system(paste("rm",GisaidSubmitFasta))
for (i in 1:nrow(DF)){
 
  ### Create a single file for sequences that pass the publishable criteria
  if((DF[i,"qc.overallStatus"]%in% c("good","mediocre")) & (DF[i,"PercCov"]>=90) & ( ! is.na(DF[i,"collection"]))){
   virus_name<-paste("hCoV-19/Spain/CT-IrsiCaixa",DF[i,"library_id"],"/",as.character(as.Date(DF[i,"collection_date"],"%Y")),sep="")
   write(paste(">",virus_name,"\n",DF[i,"FastqSequence"],sep=""),file=GisaidSubmitFasta,append=T)
   outputDF[i,"submitter"]<-gisaidSubmitter
   outputDF[i,"fn"]<-GisaidFastaFilename
   outputDF[i,"covv_virus_name"]<-virus_name
   outputDF[i,"covv_type"]<-gisaidType
   outputDF[i,"covv_passage"]<-as.character(DF[i,"passage_details"])
   outputDF[i,"covv_collection_date"]<-as.character(as.Date(DF[i,"collection_date"],"%Y-%m-%d"))
   outputDF[i,"covv_location"]<-as.character(paste("Europe","Spain","Catalunya",DF[i,"location"],sep=" / "))
   outputDF[i,"covv_add_location"]<-ifelse(is.na(DF[i,"location"]),"",DF[i,"location"])
   outputDF[i,"covv_host"]<-DF[i,"host"]                                                
   outputDF[i,"covv_add_host_info"]<-ifelse(is.na(DF[i,"host_comment"]),"",DF[i,"host_comment"])
   outputDF[i,"covv_gender"]<-DF[i,"gender"]
   outputDF[i,"covv_patient_age"]<-DF[i,"age"]
   outputDF[i,"covv_patient_status"]<-DF[i,"patient_status"]
   outputDF[i,"covv_specimen"]<-DF[i,"source"]
   outputDF[i,"covv_outbreak"]<-DF[i,"outbreak"]
   outputDF[i,"covv_last_vaccinated"]<-ifelse(is.na(DF[i,"vaccinated"]),"",DF[i,"vaccinated"])
   outputDF[i,"covv_treatment"]<-ifelse(is.na(DF[i,"treatment"]),"",DF[i,"treatment"])
   outputDF[i,"covv_seq_technology"]<-gisaidSequencingTechnology
   outputDF[i,"covv_assembly_method"]<-gisaidAssemblyMethod
   outputDF[i,"covv_coverage"]<-DF[i,"DepthOfCov"]
   outputDF[i,"covv_orig_lab"]<-DF[i,"OriginatingLab"]
   outputDF[i,"covv_orig_lab_addr"]<-DF[i,"OriginatingLabAddress"]
   outputDF[i,"covv_provider_sample_id"]<-DF[i,"sample_id"]
   outputDF[i,"covv_subm_lab"]<-gisaidSubmittingLab
   outputDF[i,"covv_subm_lab_addr"]<-gisaidSubmittingLabAddress
   outputDF[i,"covv_subm_sample_id"]<-DF[i,"library_id"]
   outputDF[i,"covv_authors"]<-paste(gisaidLocalAuthors,DF[i,"OriginatingLabAuthors"])
   outputDF[i,"covv_comment"]<-NA
   outputDF[i,"comment_type"]<-NA
  }
}
  outputDF<-outputDF[! rowSums(is.na(outputDF))==ncol(outputDF),]
write.csv(outputDF,file=GisaidSubmitCsv,row.names = F,fileEncoding = "UTF-8")
DF$passage_details

