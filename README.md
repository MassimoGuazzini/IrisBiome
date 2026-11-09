# IrisBiome - Microbiome Analysis Suite

<img src="assets/logo.png" alt="IrisBiome logo" width="160">

**Portfolio preview · v0.9.0.dev0 · In development**

Desktop workflow for paired-end 16S rRNA microbiome analysis, combining a Python/PyQt5 interface with an R/DADA2 pipeline and DOCX/XLSX reporting.

## Overview

IrisBiome demonstrates the integration of sequencing-data processing, sample metadata and automated reporting. The public repository contains the DADA2 pipeline and a reduced, runnable reporting layer. The original literature-curated interpretation layer is private.

**Start here without installing anything:** [Italian demo report](docs/IrisBiome_demo_report.docx), [English demo report](docs/IrisBiome_demo_report_en.docx), [summary workbook](examples/demo_summary.xlsx).

```text
Paired-end FASTQ → QC → filtering / primer removal → DADA2 denoising
→ ASVs → paired-end merging → chimera removal → taxonomy assignment
→ abundance table + anamnesis JSON → demonstration DOCX / XLSX reports
```

## Features

- PyQt5 interface with Pipeline, Anamnesis and Report tabs.
- DADA2 processing code for QC, denoising, ASV inference, merging and chimera removal.
- Configurable CPU usage and external taxonomic database location.
- Taxonomic assignment code paths for SILVA, RDP, Greengenes and GTDB; SILVA is the default. These integrations have not been validated end to end in this preview.
- JSON metadata linked to sample identifiers.
- Phylum and genus abundance summaries and genus-level rarefaction.
- Three arbitrary demonstration mappings showing reference-table integration, with no biological functional interpretation.
- Italian and English demonstration reports, DOCX export and XLSX summaries.

## Workflow

1. Select paired-end FASTQ files, output directory and an external taxonomy database.
2. Run QC, inspect quality plots and choose trimming lengths.
3. Run DADA2 and obtain a `Species_merged_count.txt` table.
4. Create one `<sample>_anamnesi.json` file per sample.
5. Generate demonstration reports and the summary workbook.

The included synthetic abundance table lets you start at step 4 without running DADA2. It is not a FASTQ dataset. See [workflow](docs/workflow.md).

## Screenshots

| Pipeline | Anamnesis | Report |
| --- | --- | --- |
| ![Pipeline](screenshots/gui_pipeline.png) | ![Anamnesis](screenshots/gui_anamnesis.png) | ![Report](screenshots/gui_report.png) |

## Installation

See [installation instructions](docs/installation.md) for Python, R and system dependencies. From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
Rscript R/install_dependencies.R
```

Taxonomic databases are external and excluded; see [database setup](database/README.md). R and its packages must be installed separately even when using the PyInstaller configuration. Packaging has not been validated for distribution.

## Usage

```bash
python3 IrisBiome.py
```

In the Report tab, choose the abundance table, output folder, matching anamnesis directory and language. See [usage](docs/usage.md).

## Demo Dataset

All included sample counts and metadata are synthetic. The three mappings in `data/functional_categories.xlsx` are arbitrary examples, not curated biological associations or a reduced clinical reference population.

```bash
mkdir -p /tmp/irisbiome-demo-anamnesis
cp examples/demo_anamnesi.json /tmp/irisbiome-demo-anamnesis/DEMO001_anamnesi.json
Rscript R/report.R \
  --input examples/demo_species_merged_count.txt \
  --output /tmp/irisbiome-demo-output \
  --anamnesis /tmp/irisbiome-demo-anamnesis \
  --language en
```

Use `--language it` for Italian. Both public reports contain equivalent demonstration content. User-provided free text is preserved without translation.

## Outputs

The DADA2 script writes quality plots, ASV/read-tracking tables and database-specific taxonomy/count tables.

The public reporter writes:

- `reports/Demo_<sample>_report.docx`;
- `summary_table.xlsx`, with `Summary`, `Genus_Abundance` and `Demo_Groups` sheets;
- `plots/<sample>_phylum.png` and, when classified genera are present, `plots/<sample>_rarefaction.png`.

These paths and workbook columns differ from the private reporter. The input abundance-table and anamnesis interfaces remain compatible with the GUI.

## Scientific Scope

The public reporting layer provides descriptive summaries. Relative abundances are calculated from supplied read counts; genus-level rarefaction subsamples classified genus counts and does not estimate ASV richness. Taxonomy-derived groups do not measure metabolic activity.

The public build excludes the complete functional knowledge base, reference percentiles, extended bibliography, curated thresholds, health-state rules and personalized nutritional advice. The three microbiome-state images appear only as an artwork legend; no health classification is assigned.

The complete private implementation contains the literature-curated knowledge base and extended interpretation logic. **For information about access to that version, contact [Massimo Guazzini](https://github.com/MassimoGuazzini).** Availability does not imply clinical validation.

## Limitations

- This is a portfolio preview, not a stable or clinically validated release.
- GUI startup and synthetic report generation have been checked locally. The full FASTQ → DADA2 → taxonomy → report workflow still needs validation with real input and external databases.
- Database-specific paths and taxonomic naming require validation for the chosen reference release.
- The demo has one sample and does not represent biological diversity or clinical reference intervals.
- The original private English report used condensed advice rather than a full translation. The public build omits extended advice in both languages.
- No clinical diagnosis, health-state assignment or personalized treatment recommendation is provided.

See [limitations](docs/limitations.md), [validation status](docs/validation.md) and the [roadmap](docs/roadmap.md).

## Citation

Software citation metadata is in [CITATION.cff](CITATION.cff). The DADA2 script retains its original author attribution; see [acknowledgements](docs/ACKNOWLEDGEMENTS.md).

## License

[All rights reserved](LICENSE). This is a source-visible portfolio demonstration, not an open-source license. Third-party dependencies and reference databases retain their own terms.

## Author

[Massimo Guazzini](https://github.com/MassimoGuazzini)
