# Usage

## Start The GUI

```bash
python3 IrisBiome.py
```

## Pipeline Tab

1. Select the folder containing paired-end FASTQ files.
2. Select the output folder.
3. Select the taxonomy database folder.
4. Enter primer sequences as `FWD;REV`.
5. Set CPU cores. Use `1-4` on laptops.
6. Run QC.
7. Inspect quality plots in `04_plots/`.
8. Set `TrimF` and `TrimR`.
9. Run the full pipeline.

## Anamnesis Tab

Create one JSON file per sample. The filename must match:

```text
SAMPLEID_anamnesi.json
```

If the sample column is `DEMO001`, the report expects:

```text
DEMO001_anamnesi.json
```

## Report Tab

Select:

- the `Species_merged_count.txt` table;
- an output folder;
- the folder containing anamnesis JSON files.

Then run report generation.

## Command-Line Report Demo

```bash
mkdir -p /tmp/irisbiome-demo-anamnesis
cp examples/demo_anamnesi.json /tmp/irisbiome-demo-anamnesis/DEMO001_anamnesi.json

Rscript R/report.R \
  --input examples/demo_species_merged_count.txt \
  --output /tmp/irisbiome-demo-output \
  --anamnesis /tmp/irisbiome-demo-anamnesis \
  --language en
```

Use `--language it` for an Italian report.


Updated example reports: [Italian](IrisBiome_demo_report.docx) and [English](IrisBiome_demo_report_en.docx). Both use the current IrisBiome logo and microbiome illustrations.

## Public report outputs

This preview writes `reports/Demo_<sample>_report.docx`, `summary_table.xlsx` and `plots/` under the chosen output folder. It does not use the private `filter_0.01` layout.

Counts must be non-negative integers with a positive total per sample. `Phylum` and `Genus` are required columns; recognized taxonomy ranks and `seq` are not treated as sample counts. Missing taxonomy is displayed as unclassified. Provide one JSON for each sample; a supplied `codice` must match its sample column.

The public report has no health classification or personalized advice. Its three demo mappings are arbitrary, not functional claims. Italian and English use equivalent demonstration sections; user free text stays as entered.

Run the report integration checks from the repository root:

```bash
Rscript tests/smoke_report.R
```

Sample identifiers used for report filenames may contain ASCII letters, digits, dots, underscores and hyphens, starting with a letter or digit. The public GUI exposes the `Demo` report type; legacy report-type fields in existing JSON files do not select private report logic.
