

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

articCoords<-merge(ArticBedFw,ArticBedRv,by="PrimerName")

myDF<-data.frame(matrix(ncol=2,nrow=max(articCoords$RightPos)))
colnames(myDF)<-c("Position","NumberOfAmplicons","AmpliconName")
for (position in 1:max(articCoords$RightPos)){
  print(position)
  myDF[position,"Position"]<-position
  myDF[position,"NumberOfAmplicons"]<-0
  for (i in 1:nrow(articCoords)){
    if(position>=articCoords[i,"LeftPos"] & position<=articCoords[i,"RightPos"]){
      myDF[position,"NumberOfAmplicons"]<- myDF[position,"NumberOfAmplicons"]+1
      myDF[position,"AmpliconName"]<-articCoords[i,"PrimerName"]
    }
  }
}

myCovDF<-merge(myDF,covDF,by.x="Position",by.y="position")
summary(myCovDF)
require(reshape)
myMeltDF<-melt(myCovDF,id.vars = c("Position","NumberOfAmplicons","AmpliconName","Reference","X1","X2"))
myMeltDF<-myMeltDF[myMeltDF$NumberOfAmplicons==1,]
 myMeltDF[grepl("_1",myMeltDF$AmpliconName),"Pool"]<-"Pool1"
myMeltDF[grepl("_2",myMeltDF$AmpliconName),"Pool"]<-"Pool2"
ggplot(myMeltDF,aes(x=reorder(AmpliconName, value, fun = median),y=value))+geom_boxplot()

poolDF<-read.table("~/Downloads/ARTIC_design_pools.txt",sep="\t",header=T)
poolDF$Name<-gsub("_LEFT*","",poolDF$Name)
poolDF$Name<-gsub("_RIGHT*","",poolDF$Name)
poolDF$Name<-gsub("_alt*","",poolDF$Name)
poolDF<-unique(poolDF[,c("Name","Pool")])
myMeltDF$AmpliconName
myMeltDF<-merge(myMeltDF,poolDF,by.x="AmpliconName",by.y="Name")
library(scales)
numColors <- length(levels(myMeltDF$Pool.y)) # How many colors you need
getColors <- scales::brewer_pal('qual') # Create a function that takes a number and returns a qualitative palette of that length (from the scales package)
myPalette <- getColors(numColors)
names(myPalette) <- levels(myMeltDF$Pool.y)

ggplot(myMeltDF,aes(x=reorder(AmpliconName, value, na.rm=T,FUN = median),y=value,fill=Pool.y))+
  geom_boxplot()+ theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
ggsave("~/Downloads/CoveragebyMedian.pdf",width=40,height = 20)
medianCovDF<-aggregate(value~AmpliconName,myMeltDF,median)
poolDF<-read.table("~/Downloads/ARTIC_design_pools.txt",sep="\t",header=T)
poolDF$Name<-gsub("_LEFT*","",poolDF$Name)
poolDF$Name<-gsub("_RIGHT*","",poolDF$Name)
poolDF$Name<-gsub("_alt*","",poolDF$Name)
medianPoolDF<-merge(medianCovDF,poolDF,by.x="AmpliconName",by.y="Name")
ggplot(medianPoolDF,aes(x=gc_content,y=value))+geom_point(aes(colour = tm))+scale_y_log10()
ggsave("~/Downloads/TM_GCContent_vs_Cov.pdf")
