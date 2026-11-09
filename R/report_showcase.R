# Presentation-only renderer. No clinical thresholds or private taxon/function rules.
# Functions use the helpers and translations provided by report.R.
masked_range <- "xx\u2013xx"
showcase_catalog <- function(project) {
  path <- file.path(project, "data", "showcase_functions.csv")
  x <- read.csv(path, stringsAsFactors = FALSE)
  stopifnot(all(c("Key", "Italian", "English", "Demo_Percent", "Demo_Status") %in% names(x)))
  x
}
is_showcase_fixture <- function(input, sample, project) {
  # Presentation scores may only appear for the exact shipped synthetic fixture.
  # A name match alone is insufficient: changed/real counts get placeholders.
  if (!identical(sample, "DEMO001")) return(FALSE)
  fixture <- read.delim(file.path(project, "examples", "demo_species_merged_count.txt"), check.names = FALSE, stringsAsFactors = FALSE)
  cols <- names(fixture)
  if (!all(cols %in% names(input)) || nrow(input) != nrow(fixture)) return(FALSE)
  all(vapply(cols, function(k) identical(as.character(input[[k]]), as.character(fixture[[k]])), logical(1)))
}
showcase_function_table <- function(catalog, scenario, sample) {
  data.frame(Sample = sample, Function = if (is_en) catalog$English else catalog$Italian,
             Value = if (scenario) sprintf("%.1f%%", catalog$Demo_Percent) else "xx",
             Reference = masked_range,
             Evaluation = if (scenario) vapply(catalog$Demo_Status, function(s) switch(s, low = tr("Basso (demo)", "Low (demo)"), high = tr("Alto (demo)", "High (demo)"), tr("Nella media (demo)", "Typical (demo)")), character(1)) else tr("Riservata", "Withheld"),
             Origin = if (scenario) "synthetic_presentation_fixture" else "not_computed_public", stringsAsFactors = FALSE)
}
portfolio_heading <- function(doc, title) {
  doc <- body_add_break(doc)
  body_add_par(doc, title, style = "heading 1")
}
portfolio_note <- function(doc, text) body_add_fpar(doc, fpar(ftext(text, fp_text(color = "#546775", font.size = 10))))
portfolio_table <- function(doc, frame) {
  ft <- flextable::flextable(frame)
  ft <- flextable::theme_booktabs(ft)
  ft <- flextable::fontsize(ft, size = 10, part = "all")
  ft <- flextable::color(ft, color = "#244D56", part = "header")
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::padding(ft, padding = 6, part = "all")
  ft <- flextable::set_table_properties(flextable::autofit(ft), layout = "autofit", width = 1)
  flextable::body_add_flextable(doc, ft)
}
portfolio_metadata <- function(doc, metadata, keys, labels) {
  tab <- data.frame(Field = labels, Value = vapply(keys, function(k) metadata_value(metadata, k), character(1)))
  names(tab) <- c(tr("Campo", "Field"), tr("Valore", "Value"))
  portfolio_table(doc, tab)
}
build_portfolio_report <- function(sample, metadata, counts, phyla, genera, observed, phylum_path, rare_path, function_table, scenario, plot_dir, assets) {
  doc <- read_docx(file.path(project, "templates", "report_base.docx"))
  doc <- body_set_default_section(doc, prop_section(page_size = page_size(orient = "portrait", width = 8.27, height = 11.69), page_margins = page_mar(top = .7, bottom = .7, left = .7, right = .7)))
  doc <- add_image(doc, file.path(assets, "logo.png"), 1.5)
  doc <- body_add_fpar(doc, fpar(ftext("IrisBiome", fp_text(font.size = 30, bold = TRUE, color = "#244D56"))))
  doc <- body_add_par(doc, tr("ANALISI DEL MICROBIOTA INTESTINALE", "GUT MICROBIOME ANALYSIS"), style = "heading 1")
  doc <- body_add_par(doc, tr("Report completo dimostrativo · Portfolio preview", "Full-format demonstration report · Portfolio preview"), style = "heading 2")
  doc <- body_add_par(doc, paste(tr("Campione", "Sample"), sample, "|", tr("Lingua: italiano", "Language: English")))
  doc <- body_add_par(doc, tr("Una panoramica del percorso dall'abbondanza tassonomica alla presentazione integrata dei risultati e dell'anamnesi.", "A view of the reporting workflow from taxonomic abundance to the integrated presentation of results and anamnesis."))
  doc <- portfolio_note(doc, if (scenario) tr("DATI SINTETICI. Le abbondanze tassonomiche provengono dal dataset demo. Valutazioni funzionali, stato e commenti illustrano uno scenario fittizio: non sono calcolati con le regole private. Tutti gli intervalli di riferimento sono mascherati come xx–xx.", "SYNTHETIC DATA. Taxonomic abundances come from the demo dataset. Functional evaluations, status and comments illustrate a fictional scenario: private rules are not executed. All reference intervals are masked as xx–xx.") else tr("ANTEPRIMA PUBBLICA. Le abbondanze sono calcolate dall'input; valori funzionali, soglie e valutazioni private non sono disponibili. Gli intervalli sono mostrati come xx–xx.", "PUBLIC PREVIEW. Abundances are calculated from the input; functional values, thresholds and private evaluations are unavailable. Reference intervals are shown as xx–xx."))
  doc <- body_add_par(doc, tr("Struttura del report", "Report structure"), style = "heading 2")
  doc <- body_add_par(doc, tr("1. Dati anagrafici · 2. Anamnesi · 3. Risultato e osservazioni · 4. Biodiversità · 5. Phylum e generi · 6. Enterotipo · 7. Funzioni · 8. Generi associati · 9. Taxa di interesse · 10. Commenti integrati · 11. Asse intestino-cervello · 12. Abbondanze e riferimenti", "1. Sample details · 2. Anamnesis · 3. Result and observations · 4. Biodiversity · 5. Phyla and genera · 6. Enterotype · 7. Functions · 8. Associated genera · 9. Taxa of interest · 10. Integrated comments · 11. Gut–brain axis · 12. Abundances and references"))
  doc <- portfolio_heading(doc, tr("1. Dati anagrafici", "1. Sample details"))
  doc <- portfolio_metadata(doc, metadata, c("codice", "nome", "cognome", "sesso", "data_nascita", "codice_fiscale", "indirizzo", "professionista"), if (is_en) c("Sample code", "First name", "Last name", "Sex", "Date of birth", "Tax code (fictional)", "Address (fictional)", "Referring professional") else c("Codice campione", "Nome", "Cognome", "Sesso", "Data di nascita", "Codice fiscale (fittizio)", "Indirizzo (fittizio)", "Professionista"))
  doc <- portfolio_table(doc, setNames(data.frame(c(tr("Read totali", "Total reads"), tr("Generi osservati", "Observed genera")), c(sum(counts), observed)), c(tr("Parametro", "Parameter"), tr("Valore", "Value"))))
  doc <- portfolio_note(doc, tr("L'anagrafica del campione demo riprende i dati che l'autore ha dichiarato fittizi nel referto di esempio. Il PDF originale non è incluso.", "The demo identity uses details that the author confirmed were fictional in the reference report. The original reference PDF is not included."))
  doc <- portfolio_heading(doc, tr("2. Anamnesi", "2. Anamnesis"))
  keys <- c("eta", "peso", "altezza", "intestino", "scala_bristol", "antibiotici", "reflusso", "gonfiore", "dispepsia", "meteorismo", "fumatore", "alcool", "sport", "alimentazione", "sonno", "allergie", "sintomi", "farmaci")
  labels <- if (is_en) c("Age", "Weight (kg)", "Height (cm)", "Bowel regularity", "Bristol scale", "Antibiotics", "Reflux", "Bloating", "Dyspepsia", "Flatulence", "Smoking", "Alcohol", "Physical activity", "Diet", "Sleep", "Allergies", "Symptoms", "Medication") else c("Età", "Peso (kg)", "Altezza (cm)", "Regolarità intestinale", "Scala Bristol", "Antibiotici", "Reflusso", "Gonfiore", "Dispepsia", "Meteorismo", "Fumatore", "Alcol", "Attività fisica", "Alimentazione", "Sonno", "Allergie", "Sintomi", "Farmaci")
  doc <- portfolio_metadata(doc, metadata, keys, labels)
  doc <- portfolio_heading(doc, tr("3. Risultato e osservazioni", "3. Result and observations"))
  doc <- add_image(doc, file.path(assets, "middle.png"), 1.6)
  doc <- body_add_par(doc, if (scenario) tr("Profilo intermedio — scenario dimostrativo", "Intermediate profile — demonstration scenario") else tr("Valutazione privata non disponibile", "Private evaluation unavailable"), style = "heading 2")
  doc <- portfolio_note(doc, tr("L'icona illustra la presentazione del risultato. Non costituisce una classificazione sanitaria dell'input.", "The icon illustrates result presentation. It is not a health classification of the input."))
  summary <- data.frame(Section = tr(c("Biodiversità", "Composizione", "Gruppi funzionali", "Integrazione anamnesi"), c("Biodiversity", "Composition", "Functional groups", "Anamnesis integration")), Observation = c(paste(observed, tr("generi classificati osservati", "classified genera observed")), paste(tr("Genere più abbondante:", "Most abundant genus:"), genera$Taxon[which.max(genera$Reads)]), tr("Valutazioni illustrate con dati sintetici; intervalli xx–xx", "Evaluations illustrated with synthetic data; ranges xx–xx"), tr("Metadati visualizzati; regole di personalizzazione riservate", "Metadata displayed; personalization rules withheld")))
  names(summary) <- c(tr("Area", "Area"), tr("Osservazione", "Observation")); doc <- portfolio_table(doc, summary)
  doc <- portfolio_heading(doc, tr("4. Biodiversità", "4. Biodiversity"))
  if (!is.null(rare_path)) doc <- add_image(doc, rare_path, 6.1)
  doc <- body_add_par(doc, tr("La curva mostra il numero atteso di generi al variare delle letture sottocampionate. È calcolata sui conteggi aggregati per genere ed esclude le letture non classificate; non rappresenta la ricchezza ASV.", "The curve shows expected genus richness as read subsampling depth increases. It uses genus-aggregated counts, excluding unclassified reads; it does not represent ASV richness."))
  doc <- portfolio_table(doc, setNames(data.frame(c(as.character(observed), masked_range, tr("Riservata", "Withheld"))), tr("Generi osservati / intervallo / valutazione", "Observed genera / interval / evaluation")))
  doc <- portfolio_heading(doc, tr("5. Phylum e genere", "5. Phylum and genus"))
  doc <- add_image(doc, phylum_path, 6.1)
  top <- head(genera, 12)
  chart <- ggplot(top, aes(x = reorder(Taxon, Percent), y = Percent)) + geom_col(fill = "#667DB1") + coord_flip() + labs(x = NULL, y = tr("Abbondanza relativa (%)", "Relative abundance (%)"), title = tr("Generi più rappresentati", "Most represented genera")) + theme_minimal(base_size = 11)
  genus_path <- file.path(plot_dir, paste0(sample, "_genus.png")); ggsave(genus_path, chart, width = 6.4, height = 3.7, dpi = 140)
  doc <- add_image(doc, genus_path, 6.1)
  tab <- data.frame(Taxon = phyla$Taxon, Percent = sprintf("%.2f%%", phyla$Percent), Reference = masked_range)
  names(tab) <- c("Phylum", tr("Abbondanza", "Abundance"), tr("Riferimento", "Reference")); doc <- portfolio_table(doc, tab)
  doc <- portfolio_heading(doc, tr("6. Enterotipo", "6. Enterotype"))
  comparison <- data.frame(Genus = c("Bacteroides", "Prevotella", "Ruminococcus"))
  comparison$Percent <- vapply(comparison$Genus, function(g) sum(genera$Percent[genera$Taxon == g]), numeric(1))
  if (sum(comparison$Percent) > 0) {
    pie <- ggplot(comparison, aes(x = "", y = Percent, fill = Genus)) + geom_col(width = 1, colour = "white") + coord_polar(theta = "y") + theme_void() + labs(fill = tr("Genere", "Genus")) + scale_fill_manual(values = c("#547B91", "#A1C6B4", "#D8A36B"))
    pie_path <- file.path(plot_dir, paste0(sample, "_enterotype_comparison.png")); ggsave(pie_path, pie, width = 6.1, height = 3.4, dpi = 140)
    doc <- add_image(doc, pie_path, 5.6)
  }
  comparison$Percent <- sprintf("%.2f%%", comparison$Percent); comparison$Reference <- masked_range
  names(comparison) <- c(tr("Genere", "Genus"), tr("Abbondanza sul totale", "Abundance of total"), tr("Soglia", "Threshold")); doc <- portfolio_table(doc, comparison)
  doc <- body_add_par(doc, tr("Il grafico confronta solo questi tre generi e ne rinormalizza le proporzioni. La tabella usa le percentuali sul totale delle letture. L'assegnazione dell'enterotipo e le sue soglie restano riservate.", "The chart compares only these three genera and renormalizes their proportions. The table uses percentages of total reads. Enterotype assignment and its thresholds remain withheld."))
  doc <- portfolio_heading(doc, tr("7. Funzioni del microbioma", "7. Microbiome functions"))
  doc <- portfolio_note(doc, tr("Vetrina del formato completo: le percentuali e le valutazioni demo sono inventate indipendentemente dai taxa. Non rappresentano attività metabolica misurata o inferita. Le associazioni curate non sono incluse.", "Full-format showcase: demo percentages and evaluations are invented independently of taxa. They do not represent measured or inferred metabolic activity. Curated mappings are not included."))
  ft <- function_table[,c("Function", "Value", "Reference", "Evaluation")]
  names(ft) <- c(tr("Funzione", "Function"), tr("Valore demo", "Demo value"), tr("Intervallo", "Interval"), tr("Valutazione demo", "Demo evaluation")); doc <- portfolio_table(doc, ft)
  doc <- portfolio_heading(doc, tr("8. Generi nei gruppi funzionali", "8. Genera in functional groups"))
  mapping <- data.frame(Function = function_table$Function, Genera = tr("Associazioni riservate", "Mappings withheld"))
  names(mapping) <- c(tr("Funzione", "Function"), tr("Generi associati", "Associated genera")); doc <- portfolio_table(doc, mapping)
  doc <- portfolio_heading(doc, tr("9. Taxa di interesse", "9. Taxa of interest"))
  taxa <- c("Escherichia/Shigella", "Klebsiella", "Enterococcus", "Fusobacterium")
  values <- vapply(taxa, function(g) sum(genera$Percent[genera$Taxon == g]), numeric(1))
  taxa_table <- data.frame(Genus = taxa, Percent = sprintf("%.2f%%", values), Reference = masked_range)
  names(taxa_table) <- c(tr("Genere", "Genus"), tr("Abbondanza", "Abundance"), tr("Intervallo", "Interval")); doc <- portfolio_table(doc, taxa_table)
  doc <- body_add_par(doc, tr("È una selezione tassonomica descrittiva. Un dato aggregato per genere non identifica una specie patogena né dimostra un'infezione. Non sono applicate liste o regole cliniche private.", "This is a descriptive taxonomic selection. Genus-level abundance does not identify a pathogenic species or establish infection. No private clinical lists or rules are applied."))
  doc <- portfolio_heading(doc, tr("10. Commenti integrati e nutrizione", "10. Integrated comments and nutrition"))
  doc <- body_add_par(doc, tr("Esempio di struttura del commento", "Example comment structure"), style = "heading 2")
  doc <- portfolio_table(doc, setNames(data.frame(c(metadata_value(metadata, "gonfiore"), masked_range, tr("Riservata", "Withheld"))), tr("Anamnesi / soglia / raccomandazione", "Anamnesis / threshold / recommendation")))
  doc <- body_add_par(doc, if (scenario) tr("SCENARIO DEMO — Il report completo mette in relazione osservazioni microbiologiche e anamnesi. Qui viene mostrato il collegamento visivo fra un campo anamnestico e una sezione interpretativa; il testo personalizzato e i criteri decisionali sono riservati.", "DEMO SCENARIO — The complete report connects microbiological observations and anamnesis. Here the visual link between a metadata field and an interpretation section is illustrated; personalized wording and decision criteria are withheld.") else tr("I metadati sono riportati, ma non vengono generate indicazioni nutrizionali personalizzate nella versione pubblica.", "Metadata are displayed, but the public version does not generate personalized nutritional guidance."))
  doc <- portfolio_heading(doc, tr("11. Asse intestino-cervello", "11. Gut–brain axis"))
  brain <- function_table[grepl("seroton|dopamin|gaba|noradren", tolower(function_table$Function)), c("Function", "Value", "Reference", "Evaluation")]
  names(brain) <- names(ft); doc <- portfolio_table(doc, brain)
  doc <- portfolio_note(doc, tr("Questi valori sono elementi di presentazione sintetici: non misurano neurotrasmettitori, stato neurologico o sintomi. Le regole della versione completa non sono distribuite.", "These values are synthetic presentation elements: they do not measure neurotransmitters, neurological status or symptoms. Complete-version rules are not distributed."))
  doc <- portfolio_heading(doc, tr("12. Abbondanza dei generi individuati", "12. Detected genus abundances"))
  table <- data.frame(Genus = genera$Taxon, Percent = sprintf("%.2f%%", genera$Percent), Reference = masked_range, Evaluation = tr("Riservata", "Withheld"))
  names(table) <- c(tr("Genere", "Genus"), tr("Abbondanza", "Abundance"), tr("Intervallo", "Interval"), tr("Valutazione", "Evaluation")); doc <- portfolio_table(doc, table)
  doc <- body_add_par(doc, tr("Bibliografia e versione completa", "Bibliography and complete version"), style = "heading 2")
  doc <- body_add_par(doc, tr("Bibliografia estesa, database funzionale, intervalli e criteri interpretativi sono disponibili nella versione privata. Per informazioni contattare Massimo Guazzini: https://github.com/MassimoGuazzini", "The extended bibliography, functional knowledge base, intervals and interpretation criteria belong to the private version. For information contact Massimo Guazzini: https://github.com/MassimoGuazzini"))
  doc
}
