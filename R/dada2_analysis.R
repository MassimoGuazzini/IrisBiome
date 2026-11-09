# Run with --help flag for help.

# Modified 10/09/2023 by Fabio Marroni

suppressPackageStartupMessages({

  library(optparse)

})



option_list = list(

  make_option(c("-R", "--readsdir"), type="character", default=NULL,

              help="Input file", metavar="character"),

  make_option(c("-B", "--basedir"), type="character", default=NULL,

              help="Input file", metavar="character"),

  make_option(c("-D", "--DBdir"), type="character", default=Sys.getenv("IRISBIOME_DB_DIR", Sys.getenv("FAUSTBIOME_DB_DIR", "database")),

              help="Database folder", metavar="character"),

  make_option(c("-V", "--primers"), type="character", default="AGAGTTTGATCCTGGCTCAG;TGCTGCCTCCCGTAGGAGT",

              help="primer sequence", metavar="character"),

  make_option(c("-P", "--previously_run"), type="logical", default=TRUE,

              help="Was read trimming and error estimate previously run?", metavar="character"),

  make_option(c("-M", "--max.avs"), type="numeric", default=10000,

              help="Max number of avs to classify symultaneously", metavar="character"),

  make_option(c("-S", "--use_silva"), type="logical", default=TRUE,

              help="Use silva database for classification?", metavar="character"),

  make_option(c("-r", "--use_rdp"), type="logical", default=FALSE,

              help="Use RDP database for classification?", metavar="character"),

  make_option(c("-G", "--use_greengenes"), type="logical", default=FALSE,

              help="Use greengenes database for classification?", metavar="character"),

  make_option(c("-g", "--use_GTDB"), type="logical", default=FALSE,

              help="Use greengenes database for classification?", metavar="character"),
make_option("--step", type="character", default="all",
            help="Step to run: qc or full"),
make_option("--trimF", type="integer", default=NULL,
            help="Trimming length for forward reads"),
make_option("--trimR", type="integer", default=NULL,
            help="Trimming length for reverse reads"),
make_option("--ncores", type="integer", default=4,
            help="Number of CPU cores to use [default %default]"),
  make_option(c("-F", "--filepattern"), type="character", default="",

              help="Input file", metavar="character")

)







opt_parser = OptionParser(option_list=option_list);

opt = parse_args(opt_parser);



#print("USAGE: $ 01_small_RNA.r -I input dir/ -O summarized output file")



if (is.null(opt$basedir)) {

  stop("ERROR: No basedir specified with '-I' flag.")

} else {  cat ("basedir is ", opt$basedir, "\n")

  basedir <- opt$basedir

  }

if (is.null(opt$primers)) {

  stop("ERROR: No primers specified with '-V' flag.")

} else {  cat ("primers is ", opt$primers, "\n")

  primers <- opt$primers

  }

if (is.null(opt$readsdir)) {

  stop("ERROR: No readsdir specified with '-I' flag.")

} else {  cat ("readsdir is ", opt$readsdir, "\n")

  readsdir <- opt$readsdir

  }



if (is.null(opt$DBdir)) {

  stop("ERROR: No DBdir specified with '-I' flag.")

} else {  cat ("DBdir is ", opt$DBdir, "\n")

  DBdir <- opt$DBdir

  }



if (is.null(opt$previously_run)) {

  stop("ERROR: No previously_run specified with '-R' flag.")

} else {  cat ("previously_run is ", opt$previously_run, "\n")

  previously_run <- opt$previously_run

  }



if (is.null(opt$max.avs)) {

  stop("ERROR: No max.avs specified with '-M' flag.")

} else {  cat ("max.avs is ", opt$max.avs, "\n")

  max.avs <- opt$max.avs

  }



if (is.null(opt$use_silva)) {

  stop("ERROR: No use_silva specified with '-S' flag.")

} else {  cat ("use_silva is ", opt$use_silva, "\n")

  use_silva <- opt$use_silva

  }



if (is.null(opt$use_rdp)) {

  stop("ERROR: No use_rdp specified with '-r' flag.")

} else {  cat ("use_rdp is ", opt$use_rdp, "\n")

  use_rdp <- opt$use_rdp

  }



if (is.null(opt$use_greengenes)) {

  stop("ERROR: No use_greengenes specified with '-G' flag.")

} else {  cat ("use_greengenes is ", opt$use_greengenes, "\n")

  use_greengenes <- opt$use_greengenes

  }



if (is.null(opt$use_GTDB)) {

  stop("ERROR: No use_GTDB specified with '-g' flag.")

} else {  cat ("use_GTDB is ", opt$use_GTDB, "\n")

  use_GTDB <- opt$use_GTDB

  }



if (is.null(opt$filepattern)) {

  stop("ERROR: No filepattern specified with '-I' flag.")

} else {  cat ("filepattern is ", opt$filepattern, "\n")

  filepattern <- opt$filepattern

  }









#Tutorial (https://benjjneb.github.io/dada2/tutorial.html)



#remember to activate the conda environment from shell as follows:



# export PATH=$PATH:/projects/novabreed/share/anaconda-3/bin

# source activate dada2_picrust2



library(dada2)

library(ShortRead)

library(Biostrings)

library(data.table)

library(ggplot2)
library(gridExtra)
ncores <- max(1, opt$ncores)

if(!previously_run)
{
    basedir <- paste0(basedir, "/")
  readsdir <- paste0(readsdir,"/")
dir.create(paste0(basedir, "02_reads_no_N"),recursive = TRUE)
dir.create(paste0(basedir, "03_trimmed"),recursive = TRUE)
dir.create(paste0(basedir, "04_plots"),recursive = TRUE)
dir.create(paste0(basedir, "05_tables"),recursive = TRUE)
dir.create(paste0(basedir, "06_tables_silva"),recursive = TRUE)
   #It's easier for us to keep A to E.

fnFs <- list.files(readsdir, pattern="1_001.fastq.gz", full.names = TRUE)
fnRs <- list.files(readsdir, pattern="2_001.fastq.gz", full.names = TRUE)



#In case we want to select some files

fnFs<-fnFs[grep(filepattern,fnFs)]

fnRs<-fnRs[grep(filepattern,fnRs)]
   # Extract sample names, assuming filenames have format: XXX-YYY-WWW-SAMPLENAME-ZZZ.fastq

sample.names <- sapply(strsplit(basename(fnFs), "_"), "[", 1)
if (opt$step == "qc") {

#We memorize full names of our reads. One vector for R1 (forward) and one for R2 (reverse).

#Example name: ID2274-10-P-0-2_S96_L001_R1_001.fastq.gz

#Structure: IDA-B-C-D-E_

#Where A: IDnumber, not very useful, B: Sample number, not very useful as well, C: Treatment, D: Time, E: Replicate.
#These are usually ok for 16s from IGAtech

#Primers used for analysis (The service provider should tell them which primers they used)
primer_list <- strsplit(primers, ";")[[1]]
FWD <- primer_list[1]
REV <- primer_list[2]




#Create all orientation sequences for our primers (is just to check, I should know them)

allOrients <- function(primer) {

    # Create all orientations of the input sequence

    require(Biostrings)

    dna <- DNAString(primer)  # The Biostrings works w/ DNAString objects rather than character vectors

    orients <- c(Forward = dna, Complement = complement(dna), Reverse = reverse(dna),

        RevComp = reverseComplement(dna))

    return(sapply(orients, toString))  # Convert back to character vector

}

FWD.orients <- allOrients(FWD)

REV.orients <- allOrients(REV)



#Remove reads containing Ns, because they can cause problems. Reads are saved in the trimmed_no_N directory
fnFs.filtN <- file.path(paste(basedir,"02_reads_no_N/",basename(fnFs),sep="")) # Put N-filterd files in filtN/ subdirectory

fnRs.filtN <- file.path(paste(basedir,"02_reads_no_N/",basename(fnRs),sep="")) # Put N-filterd files in filtN/ subdirectory

filterAndTrim(fnFs, fnFs.filtN, fnRs, fnRs.filtN, maxN = 0, truncLen=0, compress = T, multithread = ncores)





#Count primers found in the reads, using all the possible primer orientation.

#We use just the first file, because all the files have the same library preparation.

primerHits <- function(primer, fn) {

    # Counts number of reads in which the primer is found

    nhits <- vcountPattern(primer, sread(readFastq(fn)), fixed = FALSE)

    return(sum(nhits > 0))

}

beforeprimer <- rbind(FWD.ForwardReads = sapply(FWD.orients, primerHits, fn = fnFs.filtN[[1]]),

    FWD.ReverseReads = sapply(FWD.orients, primerHits, fn = fnRs.filtN[[1]]),

    REV.ForwardReads = sapply(REV.orients, primerHits, fn = fnFs.filtN[[1]]),

    REV.ReverseReads = sapply(REV.orients, primerHits, fn = fnRs.filtN[[1]]))







                 # Forward Complement Reverse RevComp

# FWD.ForwardReads   47591          0       0       0

# FWD.ReverseReads      10          0       0       1

# REV.ForwardReads      10          0       0      25

# REV.ReverseReads   59812          0       0       0





#Ok, we have a lot of primers.

#Let's see if we can remove them using the filtering function of dada2



#This functions simply removes the firs N bases of the reads. It is ok when we know that the primer is at the beginning (or end) of the reads.

#In our case is should be this case.

#For more complex scenarios we may run cutadapt. It would be an easy task, but requires the software installed.



#Remove reads containing Ns, because they can cause problems. Reads are saved in the trimmed_no_N directory
fnFs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnFs),sep="")) # Put N-filterd files in filtN/ subdirectory

fnRs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnRs),sep="")) # Put N-filterd files in filtN/ subdirectory

filterAndTrim(fnFs, fnFs.filtN, fnRs, fnRs.filtN, maxN = 0, trimLeft=c(20,19), compress = T, multithread = ncores)



afterprimer <- rbind(FWD.ForwardReads = sapply(FWD.orients, primerHits, fn = fnFs.filtN[[1]]),

    FWD.ReverseReads = sapply(FWD.orients, primerHits, fn = fnRs.filtN[[1]]),

    REV.ForwardReads = sapply(REV.orients, primerHits, fn = fnFs.filtN[[1]]),

    REV.ReverseReads = sapply(REV.orients, primerHits, fn = fnRs.filtN[[1]]))


print("test")
#We can more ore less be happy!!!

                 # Forward Complement Reverse RevComp

# FWD.ForwardReads      41          0       0       0

# FWD.ReverseReads       0          0       0       1

# REV.ForwardReads       0          0       0      25

# REV.ReverseReads       0          0       0       0
#Plot quality of bases
# Helper to split a list into chunks
split_chunks <- function(x, n) {
  split(x, ceiling(seq_along(x) / n))
}

# -------- FORWARD --------
fwd_plots <- lapply(fnFs.filtN, function(file) {
  plotQualityProfile(file) + ggtitle(basename(file))
})

fwd_groups <- split_chunks(fwd_plots, 9)

pdf(file = paste0(basedir, "04_plots/", filepattern,"quality_forward.pdf"), width = 10, height = 10)
for (group in fwd_groups) {
  do.call(grid.arrange, c(group, ncol = 3))
}
dev.off()

# -------- REVERSE --------
rev_plots <- lapply(fnRs.filtN, function(file) {
  plotQualityProfile(file) + ggtitle(basename(file))
})

rev_groups <- split_chunks(rev_plots, 9)

pdf(file = paste0(basedir, "04_plots/", filepattern,"quality_reverse.pdf"), width = 10, height = 10)
for (group in rev_groups) {
  do.call(grid.arrange, c(group, ncol = 3))
}
dev.off()
#After examining the plots I noticed that the last bases of forward and reverse reads are of low quality.
#In order to avoid losing overlapping reads I cut a bit, although sequence is dropping earlier
fnFs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnFs),sep="")) # Put N-filterd files in filtN/ subdirectory
fnRs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnRs),sep="")) # Put N-filterd files in filtN/ subdirectory
  cat("Qualità generata, ora scegli trim.\n")
  quit(save="no")
}
}
if (opt$step == "full") {
  fnFs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnFs),sep="")) # Put N-filterd files in filtN/ subdirectory
  fnRs.filtN <- file.path(paste(basedir,"03_trimmed/",basename(fnRs),sep="")) # Put N-filterd files in filtN/ subdirectory
  truncF <- opt$trimF
  truncR <- opt$trimR
  out <- filterAndTrim(fnFs, fnFs.filtN,
                       fnRs, fnRs.filtN,
                       maxN = 0,
                       truncLen=c(truncF, truncR),
                       trimLeft=c(20,19),
                       compress = TRUE,
                       multithread = ncores)

pdf(paste0(basedir,"04_plots/",filepattern,"quality_nolow_F.pdf"))
plotQualityProfile(fnFs.filtN)
dev.off()
pdf(paste0(basedir,"04_plots/",filepattern,"quality_nolow_R.pdf"))
plotQualityProfile(fnRs.filtN)
dev.off()
#Now, to correctly estimate error rates we need to run an error-learning algorithm.
#This will help in discriminating true variants from sequencing errors
#Compute new error probabilitites
existing <- file.exists(fnFs.filtN) & file.exists(fnRs.filtN)
fnFs.filtN <- fnFs.filtN[existing]
fnRs.filtN <- fnRs.filtN[existing]
sample.names <- sample.names[existing]
out <- out[existing, ]
errF <- learnErrors(fnFs.filtN, multithread=ncores)
errR <- learnErrors(fnRs.filtN, multithread=ncores)
pdf(paste0(basedir,"04_plots/",filepattern,"errors_nolow_F.pdf"))
plotErrors(errF, nominalQ=TRUE)
dev.off()
pdf(paste0(basedir,"04_plots/",filepattern,"errors_nolow_R.pdf"))
plotErrors(errR, nominalQ=TRUE)
dev.off()
#Prepare dada sets using the newly estimated errors on the filtered reads
#Sample inference
dadaFs <- dada(fnFs.filtN, err=errF, multithread=ncores)
dadaRs <- dada(fnRs.filtN, err=errR, multithread=ncores)
#Merge overlapping reads. Reads that do not overlap will not merge
mergers <- mergePairs(dadaFs, fnFs.filtN, dadaRs, fnRs.filtN, verbose=TRUE, returnRejects=FALSE)
# If we think we lost too many reads we may increase the read length we allow for when trimming.
# In this case they are enough... we may even consider to increase trimming for better quality at the epenses of losing some reads.
# 41314 paired-reads (in 977 unique pairings) successfully merged out of 52970 (in 3739 pairings) input.
#Build sequence tabs for merged reads
merged_seqtab <- makeSequenceTable(mergers)
dim(merged_seqtab)
#Remove chimeras
merged_seqtab.nochim <- removeBimeraDenovo(merged_seqtab, method="consensus", multithread=ncores, verbose=TRUE)
dim(merged_seqtab.nochim)
#Write the table to file.
#This is a very important result, since it gives the count of each sequence per sample!
#It is also used to see if we previously ran dada2.
merged_nochim<-t(merged_seqtab.nochim)
write.table(merged_nochim,paste0(basedir,"/05_tables/",filepattern,"merged_nochim.txt"),sep="\t",quote=F,col.names = NA)
#Track how many reads passed the QC steps
getN <- function(x) sum(getUniques(x))
if(ncol(merged_nochim)>1)
{
#Multi sample
track <- cbind(out, sapply(dadaFs, getN), sapply(dadaRs, getN), sapply(mergers, getN), rowSums(merged_seqtab.nochim))
# If processing a single sample, remove the sapply calls: e.g. replace sapply(dadaFs, getN) with getN(dadaFs)
colnames(track) <- c("input", "filtered", "denoisedF", "denoisedR", "merged", "nonchim")
rownames(track) <- sample.names
}else{
#Single sample
track <- cbind(out, getN(dadaFs), getN(dadaRs), getN(mergers), rowSums(merged_seqtab.nochim))
colnames(track) <- c("input", "filtered", "denoisedF", "denoisedR", "merged", "nonchim")
rownames(track) <- sample.names
}
head(track)
write.table(track,paste0(basedir,"/05_tables/",filepattern,"reads_numbers_merged.txt"),row.names=F)
}



#merged_nochim<-data.frame(cbind(row.names(merged_nochim),merged_nochim))



#If we already ran dada2 we can run faster

library(dada2)

library(ShortRead)

library(Biostrings)

library(data.table)

library(ggplot2)

fnFs <- list.files(readsdir, pattern="1_001.fastq.gz", full.names = TRUE)
fnRs <- list.files(readsdir, pattern="2_001.fastq.gz", full.names = TRUE)
#In case we want to select some files
fnFs<-fnFs[grep(filepattern,fnFs)]
fnRs<-fnRs[grep(filepattern,fnRs)]
# Extract sample names, assuming filenames have format: XXX-YYY-WWW-SAMPLENAME-ZZZ.fastq
sample.names <- sapply(strsplit(basename(fnFs), "_"), "[", 1)
cat("Aggregating AVS and counting them\n")
merged_nochim<-fread(paste0(basedir,"/05_tables/",filepattern,"merged_nochim.txt"),data.table=F)
merged_nochim<-aggregate(merged_nochim[,2:ncol(merged_nochim)],by=list(merged_nochim$V1),FUN="sum")
row.names(merged_nochim)<-merged_nochim$Group.1
merged_nochim$Group.1<-NULL
merged_seqtab.nochim<-t(merged_nochim)
merged_nochim<-data.frame(cbind(row.names(merged_nochim),merged_nochim))
names(merged_nochim)<-c("seq",sample.names)






#Classify reads



if(use_silva)

{

gc()

#Silva

cat("Using Silva DB\n")

myfasta<- paste0(DBdir,"/dada2/silva/silva_old/silva_nr_v128_train_set.fa.gz")
merged_taxa <- assignTaxonomy(merged_seqtab.nochim, myfasta, minBoot=50, multithread=ncores)
write.table(merged_taxa,paste0(basedir,"/06_tables_silva/",filepattern,"Taxa_merged.txt"),quote=F,col.names = NA)
species_fasta<-paste0(DBdir,"/dada2/silva/silva_old/silva_species_assignment_v128.fa.gz")
#Trick to reduce mem usage
if(nrow(merged_taxa)>max.avs)
{
myseq<-c(seq(0,nrow(merged_taxa),by=max.avs),nrow(merged_taxa))
for(aaa in 2:length(myseq))
{
cat("Analyzing avs from",1+myseq[(aaa-1)],"to",myseq[aaa],"\n")
tset<-merged_taxa[(1+myseq[(aaa-1)]):myseq[aaa],]
tempspecies <- addSpecies(tset, species_fasta,n=1000)
ifelse(aaa==2,tspecies<-tempspecies,tspecies<-rbind(tempspecies,tspecies))
}
} else tspecies <- addSpecies(merged_taxa, species_fasta,n=1000)
#Clean up memory
rm(list=c("merged_taxa","species_fasta"))
merged_species<-data.frame(cbind(row.names(tspecies),tspecies))
names(merged_species)[1]<-"seq"
write.table(merged_species,paste0(basedir,"/06_tables_silva/",filepattern,"Species_merged.txt"),sep="\t",quote=F,row.names = F)
row.names(merged_species)<-NULL
myin<-merge(merged_nochim,merged_species,by="seq")
write.table(myin,paste0(basedir,"/06_tables_silva/",filepattern,"Species_merged_count.txt"),quote=F,sep="\t",row.names=F)
}



if(use_rdp)

{

#RDP

gc()

cat("Using RDB DB\n")

dir.create(paste0(basedir,"/07_tables_greengenes_RDP/"))

myfasta<-paste0(DBdir,"/dada2/rdp/rdp_19_toGenus_trainset.fa.gz")

merged_taxa <- assignTaxonomy(merged_seqtab.nochim, myfasta, minBoot=50, multithread=ncores)

write.table(merged_taxa,paste0(basedir,"/07_tables_RDP/",filepattern,"Taxa_merged.txt"),quote=F,col.names = NA)

species_fasta<-paste0(DBdir,"/dada2/rdp/rdp_19_toSpecies_trainset.fa.gz")

#Trick to reduce mem usage

if(nrow(merged_taxa)>max.avs)

{

myseq<-c(seq(0,nrow(merged_taxa),by=max.avs),nrow(merged_taxa))

for(aaa in 2:length(myseq))

{

tset<-merged_taxa[(1+myseq[(aaa-1)]):myseq[aaa],]

tempspecies <- addSpecies(tset, species_fasta,n=1000)

ifelse(aaa==2,tspecies<-tempspecies,tspecies<-rbind(tempspecies,tspecies))

}

} else tspecies <- addSpecies(merged_taxa, species_fasta,n=1000)

#Clean up memory

rm(list=c("merged_taxa","species_fasta"))

merged_species<-data.frame(cbind(row.names(tspecies),tspecies))

names(merged_species)[1]<-"seq"

write.table(merged_species,paste0(basedir,"/07_tables_RDP/",filepattern,"Species_merged.txt"),sep="\t",quote=F,row.names = F)

row.names(merged_species)<-NULL

myin<-merge(merged_nochim,merged_species,by="seq")

write.table(myin,paste0(basedir,"/07_tables_RDP/",filepattern,"Species_merged_count.txt"),quote=F,sep="\t",row.names=F)

}



if(use_greengenes)

{

#greengenes

cat("Using Greengenes DB\n")

gc()

dir.create(paste0(basedir,"/08_tables_GreenGenes/"))

myfasta<-paste0(DBdir,"/dada2/greengenes/gg2_2024_09_toGenus_trainset.fa.gz")

merged_taxa <- assignTaxonomy(merged_seqtab.nochim, myfasta, minBoot=50, multithread=ncores)

write.table(merged_taxa,paste0(basedir,"/08_tables_GreenGenes/",filepattern,"Taxa_merged.txt"),quote=F,col.names = NA)

species_fasta<-paste0(DBdir,"/dada2/greengenes/gg2_2024_09_toSpecies_trainset.fa.gz")

#Trick to reduce mem usage

if(nrow(merged_taxa)>max.avs)

{

myseq<-c(seq(0,nrow(merged_taxa),by=max.avs),nrow(merged_taxa))

for(aaa in 2:length(myseq))

{

tset<-merged_taxa[(1+myseq[(aaa-1)]):myseq[aaa],]

tempspecies <- addSpecies(tset, species_fasta,n=1000)

ifelse(aaa==2,tspecies<-tempspecies,tspecies<-rbind(tempspecies,tspecies))

}

} else tspecies <- addSpecies(merged_taxa, species_fasta,n=1000)

#Clean up memory

rm(list=c("merged_taxa","species_fasta"))

merged_species<-data.frame(cbind(row.names(tspecies),tspecies))

names(merged_species)[1]<-"seq"

write.table(merged_species,paste0(basedir,"/08_tables_GreenGenes/",filepattern,"Species_merged.txt"),sep="\t",quote=F,row.names = F)

row.names(merged_species)<-NULL

myin<-merge(merged_nochim,merged_species,by="seq")

write.table(myin,paste0(basedir,"/08_tables_GreenGenes/",filepattern,"Species_merged_count.txt"),quote=F,sep="\t",row.names=F)

}



if(use_GTDB)

{

#RDP

cat("Using GTDB DB\n")

gc()

dir.create(paste0(basedir,"/09_tables_GTDB/"))

myfasta<-paste0(DBdir,"/GTDB/GTDB_bac120_arc53_ssu_r214_fullTaxo.fa.gz")

merged_taxa <- assignTaxonomy(merged_seqtab.nochim, myfasta, minBoot=50, multithread=ncores)

write.table(merged_taxa,paste0(basedir,"/09_tables_GTDB/",filepattern,"Taxa_merged.txt"),quote=F,col.names = NA)

species_fasta<-paste0(DBdir,"/GTDB/GTDB_bac120_arc53_ssu_r214_species.fa.gz")

#Trick to reduce mem usage

gc()

if(nrow(merged_taxa)>max.avs)

{

myseq<-c(seq(0,nrow(merged_taxa),by=max.avs),nrow(merged_taxa))

for(aaa in 2:length(myseq))

{

tset<-merged_taxa[(1+myseq[(aaa-1)]):myseq[aaa],]

tempspecies <- addSpecies(tset, species_fasta,n=1000)

ifelse(aaa==2,tspecies<-tempspecies,tspecies<-rbind(tempspecies,tspecies))

}

} else tspecies <- addSpecies(merged_taxa, species_fasta,n=1000)

#Clean up memory

rm(list=c("merged_taxa","species_fasta"))

merged_species<-data.frame(cbind(row.names(tspecies),tspecies))

names(merged_species)[1]<-"seq"

write.table(merged_species,paste0(basedir,"/09_tables_GTDB/",filepattern,"Species_merged.txt"),sep="\t",quote=F,row.names = F)

row.names(merged_species)<-NULL

myin<-merge(merged_nochim,merged_species,by="seq")

write.table(myin,paste0(basedir,"/09_tables_GTDB/",filepattern,"Species_merged_count.txt"),quote=F,sep="\t",row.names=F)

}
