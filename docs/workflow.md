# Workflow

```text
FASTQ
  ↓
Quality control
  ↓
Primer removal / filtering
  ↓
DADA2 denoising
  ↓
ASV inference
  ↓
Paired-end merging
  ↓
Chimera removal
  ↓
Taxonomic assignment
  ↓
Microbiome analysis
  ↓
Automated reporting
```

## Processing

The DADA2 pipeline performs filtering, trimming, error learning, ASV inference, paired-end merging, chimera removal and taxonomy assignment.

## Reporting

The reporting script consumes `Species_merged_count.txt` and per-sample anamnesis JSON files. It generates descriptive demonstration DOCX reports in `reports/`, an XLSX summary table and plots. Three arbitrary reference-table mappings are demonstrated; private biological interpretation and advice are excluded.

## Metadata Matching

Sample names in the taxonomy/count table are matched against anamnesis files by filename:

```text
<sample_name>_anamnesi.json
```

