# IrisBiome public portfolio reporter. Private curated interpretation is excluded.
required <- c("optparse", "jsonlite", "openxlsx", "ggplot2", "vegan", "officer", "flextable", "magick")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", "), ". Run Rscript R/install_dependencies.R.")
suppressPackageStartupMessages({library(optparse); library(officer); library(ggplot2)})
options <- list(
  make_option("--input", type = "character", help = "DADA2 Species_merged_count.txt"),
  make_option("--output", type = "character", help = "Output directory"),
  make_option("--anamnesis", type = "character", help = "Directory containing SAMPLE_anamnesi.json"),
  make_option("--language", type = "character", default = "it", help = "it or en [default %default]")
)
opt <- parse_args(OptionParser(option_list = options))
for (key in c("input", "output", "anamnesis")) if (is.null(opt[[key]])) stop("Missing --", key)
if (!opt$language %in% c("it", "en")) stop("--language must be it or en")
is_en <- opt$language == "en"
tr <- function(it, en) if (is_en) en else it
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
project <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
assets <- file.path(project, "assets")
source(file.path(project, "R", "report_showcase.R"), local = TRUE)
catalog <- showcase_catalog(project)
input <- read.delim(opt$input, check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("", "NA"))
ranks <- c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")
if (!all(c("Phylum", "Genus") %in% names(input))) stop("Input must contain Phylum and Genus columns")
if (anyDuplicated(names(input))) stop("Duplicate input column names")
samples <- setdiff(names(input), c("seq", ranks))
if (!length(samples) || !nrow(input)) stop("Input must contain counts and at least one sample")
# Validate everything before writing outputs; identifiers also become filenames.
for (sample in samples) {
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", sample)) stop("Unsafe sample identifier: ", sample)
  counts <- suppressWarnings(as.numeric(input[[sample]]))
  if (any(!is.finite(counts) | counts < 0 | counts != floor(counts)) || sum(counts) <= 0 || sum(counts) > .Machine$integer.max) stop("Invalid read counts in ", sample)
  input[[sample]] <- counts
  path <- file.path(opt$anamnesis, paste0(sample, "_anamnesi.json"))
  if (!file.exists(path)) stop("Missing anamnesis JSON: ", path)
  metadata <- jsonlite::fromJSON(path)
  if (!is.list(metadata) || !is.null(metadata$codice) && !identical(as.character(metadata$codice), sample)) stop("Anamnesis sample code mismatch: ", sample)
}
# Exactly three arbitrary mappings. These do not describe biological functions.
rules <- openxlsx::read.xlsx(file.path(project, "data", "functional_categories.xlsx"), sheet = "Demo")
if (!identical(names(rules), c("Group", "Genus", "Description")) || nrow(rules) != 3L || anyNA(rules)) stop("Invalid demonstration mapping table")
add_table <- function(doc, frame) {
  ft <- flextable::flextable(frame)
  ft <- flextable::fontsize(ft, size = 9, part = "all")
  ft <- flextable::set_table_properties(flextable::autofit(ft), layout = "autofit", width = 1)
  flextable::body_add_flextable(doc, ft)
}
add_image <- function(doc, path, width) {
  size <- magick::image_info(magick::image_read(path))[1, ]
  body_add_img(doc, src = path, width = width, height = width * size$height / size$width)
}
clean_rank <- function(x) {
  x <- sub("^[a-z]__", "", as.character(x))
  x[is.na(x) | !nzchar(x)] <- "Unclassified"
  x
}
aggregate_rank <- function(rank, counts) {
  x <- aggregate(counts, list(Taxon = clean_rank(input[[rank]])), sum)
  names(x)[2] <- "Reads"
  x$Percent <- 100 * x$Reads / sum(counts)
  x[order(-x$Reads, x$Taxon), , drop = FALSE]
}
metadata_value <- function(metadata, key) {
  value <- metadata[[key]]
  if (is.null(value) || !length(value)) return(tr("Non fornito", "Not provided"))
  text <- paste(as.character(value), collapse = ", ")
  if (!nzchar(text)) return(tr("Non fornito", "Not provided"))
  translations <- c("Sì" = "Yes", "No" = "No", "Regolare" = "Regular", "Stipsi" = "Constipation", "Diarroico" = "Diarrhoeal", "Alternato" = "Alternating")
  if (is_en && text %in% names(translations)) text <- unname(translations[[text]])
  text
}
notice <- tr(
  "ANTEPRIMA PORTFOLIO — dati e gruppi dimostrativi. Nessuna classificazione sanitaria, soglia clinica o raccomandazione personalizzata. I gruppi A/B/C sono associazioni arbitrarie senza significato funzionale biologico.",
  "PORTFOLIO PREVIEW — demonstration data and groups. No health classification, clinical thresholds or personalized recommendations. Groups A/B/C are arbitrary mappings without biological functional meaning."
)
report_dir <- file.path(opt$output, "reports")
plot_dir <- file.path(opt$output, "plots")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
summary_rows <- genus_rows <- group_rows <- showcase_rows <- list()
for (sample in samples) {
  counts <- input[[sample]]
  metadata <- jsonlite::fromJSON(file.path(opt$anamnesis, paste0(sample, "_anamnesi.json")))
  phyla <- aggregate_rank("Phylum", counts)
  genera <- aggregate_rank("Genus", counts)
  genus_counts <- genera$Reads[genera$Taxon != "Unclassified" & genera$Reads > 0]
  observed <- length(genus_counts)
  groups <- data.frame(Group = rules$Group, Genus = rules$Genus, Percent = vapply(rules$Genus, function(g) sum(genera$Percent[genera$Taxon == g]), numeric(1)))
  groups$Group <- tr(paste("Gruppo demo", rules$Group), paste("Demo group", rules$Group))
  summary_rows[[sample]] <- data.frame(Sample = sample, Total_Reads = sum(counts), Observed_Classified_Genera = observed, Report_Mode = "portfolio_demo")
  genus_rows[[sample]] <- data.frame(Sample = sample, genera)
  group_rows[[sample]] <- data.frame(Sample = sample, groups)
  phylum_plot <- ggplot(phyla, aes(x = reorder(Taxon, Percent), y = Percent)) + geom_col(fill = "#4a9b91") + coord_flip() + labs(x = NULL, y = tr("Abbondanza relativa (%)", "Relative abundance (%)"), title = tr("Composizione per phylum", "Phylum composition")) + theme_minimal(base_size = 11)
  phylum_path <- file.path(plot_dir, paste0(sample, "_phylum.png"))
  ggsave(phylum_path, phylum_plot, width = 6.4, height = 3.6, dpi = 140)
  # Expected genus richness by subsampling classified-genus read counts.
  rare_path <- NULL
  if (length(genus_counts)) {
    depths <- unique(round(seq(0, sum(genus_counts), length.out = 60)))
    # vegan warns when abundance fixtures have no singletons; this is expected
    # for synthetic counts and does not invalidate the hypergeometric calculation.
    expected <- withCallingHandlers(
      vapply(depths, function(n) as.numeric(vegan::rarefy(matrix(genus_counts, nrow = 1), sample = n)), numeric(1)),
      warning = function(w) {
        if (startsWith(conditionMessage(w), "most observed count data have counts 1")) invokeRestart("muffleWarning")
      }
    )
    rare <- ggplot(data.frame(Reads = depths, Genera = expected), aes(Reads, Genera)) + geom_line(colour = "#4a9b91") + labs(x = tr("Read classificate sottocampionate", "Subsampled classified reads"), y = tr("Generi attesi", "Expected genera"), title = tr("Rarefazione a livello di genere", "Genus-level rarefaction")) + theme_minimal(base_size = 11)
    rare_path <- file.path(plot_dir, paste0(sample, "_rarefaction.png"))
    ggsave(rare_path, rare, width = 6.4, height = 3.6, dpi = 140)
  }
  scenario <- is_showcase_fixture(input, sample, project)
  function_table <- showcase_function_table(catalog, scenario, sample)
  showcase_rows[[sample]] <- function_table
  doc <- build_portfolio_report(sample, metadata, counts, phyla, genera, observed, phylum_path, rare_path, function_table, scenario, plot_dir, assets)
  print(doc, target = file.path(report_dir, paste0("Demo_", sample, "_report.docx")))
}
summary <- do.call(rbind, summary_rows)
rownames(summary) <- NULL
openxlsx::write.xlsx(list(Summary = summary, Genus_Abundance = do.call(rbind, genus_rows), Demo_Groups = do.call(rbind, group_rows), Showcase_Functions = do.call(rbind, showcase_rows)), file.path(opt$output, "summary_table.xlsx"), overwrite = TRUE)
cat("Portfolio demo reports generated in ", normalizePath(report_dir), "\n", sep = "")
