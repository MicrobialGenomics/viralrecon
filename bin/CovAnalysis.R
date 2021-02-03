

myWD<-"/Users/mnoguera/Downloads/coverage"
myFiles<-list.files(myWD,pattern = "*.tsv",full.names = T)

length(myFiles)
covDF<-read.table(file=myFiles[1],sep="\t",header=F)
colname<-basename(myFiles[1])
colname=gsub(".mkD.sorted.cov.tsv","",colname)
colnames(covDF)<-c("Reference","position",colname)

for (i in 2:length(myFiles)){
  if(file.info(myFiles[i])$size > 0 ){
  auxDF<-read.table(file=myFiles[i],sep="\t",header=F)
  colname<-basename(myFiles[i])
  colname=gsub(".mkD.sorted.cov.tsv","",colname)
  colnames(auxDF)<-c("Reference","position",colname)
  # auxDF$Reference<-NULL
  covDF<-merge(covDF,auxDF,by=c("Reference","position"),all=T)
  }       
}

covDF$position<-as.numeric(covDF$position)
covDFMelt<-reshape::melt(covDF,id=c("Reference","position"))
covDFMelt$variable<-as.factor(covDFMelt$variable)
require(ggplot2)
ggplot(covDFMelt,aes(x=position,y=value,color=variable))+geom_line(aes(color=variable),size=0.021)+theme(legend.position = "none")+
  theme(axis.text.y = element_text(colour = 'black', size = 12), axis.title.y = element_text(size = 12,  hjust = 0.5, vjust = 0.2)) + 
  theme(strip.text.y = element_text(size = 11, hjust = 0.5, vjust =    0.5, face = 'bold'))+scale_y_sqrt()

ArticBed<-read.table("~/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/ArticPrimers_BediVar.bed",sep="\t",header=F)
ArticBed<-ArticBed[(! grepl("alt",ArticBed$V4)),]
ArticBedFw<-ArticBed[grepl("LEFT",ArticBed$V4),]
ArticBedRv<-ArticBed[grepl("RIGHT",ArticBed$V4),]

ArticBedFw<-ArticBedFw[,c(3,4)]
ArticBedRv<-ArticBedRv[,c(2,4)]

ArticBedFw$V4<-gsub("_LEFT_LEFT","",ArticBedFw$V4)
ArticBedRv$V4<-gsub("_RIGHT_RIGHT","",ArticBedRv$V4)

colnames(ArticBedFw)<-c("LeftPos","PrimerName")
colnames(ArticBedRv)<-c("RightPos","PrimerName")

merge(ArticBedFw,ArticBedRv,by="PrimerName")
