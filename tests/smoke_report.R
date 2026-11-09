# Integration check: actual CLI, multisample counts, XLSX totals and rejected inputs.
# Run from the repository root after installing public report dependencies.
stopifnot(file.exists('R/report.R'))
work <- tempfile('irisbiome-integration-')
dir.create(work)
report_script <- normalizePath('R/report.R')
metadata_dir <- file.path(work,'anamnesis')
dir.create(metadata_dir)
table <- read.delim('examples/demo_species_merged_count.txt', check.names=FALSE)
table$DEMO002 <- rev(table$DEMO001)
table$Genus[1] <- NA_character_
for (sample in c('DEMO001','DEMO002')) jsonlite::write_json(list(codice=sample, eta=30, antibiotici='No'), file.path(metadata_dir,paste0(sample,'_anamnesi.json')), auto_unbox=TRUE)
input <- file.path(work,'counts.txt')
write.table(table,input,sep='\t',row.names=FALSE,quote=FALSE)
run <- function(input_path, output_path, language='en', success=TRUE, error=NULL) {
 log <- tempfile(tmpdir=work)
 args <- c(report_script,'--input', input_path, '--output',output_path,'--anamnesis',metadata_dir,'--language',language)
 old_dir <- setwd(work)
 on.exit(setwd(old_dir), add=TRUE)
 status <- suppressWarnings(system2(file.path(R.home('bin'),'Rscript'), shQuote(args), stdout=log, stderr=log))
 if (success && status!=0L) stop(paste(readLines(log),collapse='\n'))
 if (!success) {
  stopifnot(status!=0L, !dir.exists(output_path))
  if (!is.null(error)) stopifnot(any(grepl(error,readLines(log),fixed=TRUE)))
 }
}
out <- file.path(work,'output')
run(input,out)
summary <- openxlsx::read.xlsx(file.path(out,'summary_table.xlsx'),sheet='Summary')
stopifnot(nrow(summary)==2L, all(summary$Total_Reads==sum(table$DEMO001)), all(summary$Observed_Classified_Genera==9L))
genera <- openxlsx::read.xlsx(file.path(out,'summary_table.xlsx'),sheet='Genus_Abundance')
stopifnot(all(abs(tapply(genera$Percent,genera$Sample,sum)-100)<1e-8), 'Unclassified' %in% genera$Taxon)
groups <- openxlsx::read.xlsx(file.path(out,'summary_table.xlsx'),sheet='Demo_Groups')
stopifnot(nrow(groups)==6L, all(groups$Percent[groups$Genus=='Faecalibacterium']==0))
for (sample in c('DEMO001','DEMO002')) {
 doc <- file.path(out,'reports',paste0('Demo_',sample,'_report.docx'))
 stopifnot(file.exists(doc), 'word/document.xml' %in% unzip(doc,list=TRUE)$Name)
 stopifnot(file.exists(file.path(out,'plots',paste0(sample,'_rarefaction.png'))))
}
# Invalid counts and metadata fail before partial reports are written.
bad <- table; bad$DEMO001[1] <- -1
bad_path <- file.path(work,'negative.txt'); write.table(bad,bad_path,sep='\t',row.names=FALSE,quote=FALSE)
run(bad_path,file.path(work,'negative'),success=FALSE,error='Invalid read counts')
bad$DEMO001 <- 0
write.table(bad,bad_path,sep='\t',row.names=FALSE,quote=FALSE)
run(bad_path,file.path(work,'zero'),success=FALSE,error='Invalid read counts')
jsonlite::write_json(list(codice='WRONG'),file.path(metadata_dir,'DEMO002_anamnesi.json'),auto_unbox=TRUE)
run(input,file.path(work,'mismatch'),success=FALSE,error='Anamnesis sample code mismatch')
cat('Report integration checks passed: multisample counts, unclassified taxa, mapping isolation, XLSX totals, invalid counts and metadata mismatch.\n')
cat('Temporary artifacts:',work,'\n')
