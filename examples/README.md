# Synthetic demo data

The files in this folder are synthetic examples for portfolio and smoke-test use. The demo identity is reproduced from the reference report with the author’s confirmation that those details are fictional.

- `demo_species_merged_count.txt` mimics the DADA2 taxonomy/count table consumed by `R/report.R`.
- `demo_anamnesi.json` mimics the GUI anamnesis JSON for sample `DEMO001`.
- `demo_report.docx` is a generated Italian demo report with the IrisBiome branding.
- `demo_report_en.docx` is the English demo report.
- `demo_summary.xlsx` is the generated summary workbook.

To test report generation after installing R dependencies:

```bash
mkdir -p /tmp/irisbiome-demo-anamnesis
cp examples/demo_anamnesi.json /tmp/irisbiome-demo-anamnesis/DEMO001_anamnesi.json
Rscript R/report.R \
  --input examples/demo_species_merged_count.txt \
  --output /tmp/irisbiome-demo-output \
  --anamnesis /tmp/irisbiome-demo-anamnesis \
  --language en
```


The demo reports and workbook are generated with the public reporter. They contain no private thresholds or curated functional data. Groups A/B/C are arbitrary illustrations, not biological categories. The status illustration is a fictional scenario, not a classification. The full-format report uses `xx–xx` reference intervals and synthetic functional scores only for the exact shipped input fixture.
