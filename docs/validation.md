# Validation status

Checked locally on 2026-11-09. This records development checks, not clinical validation or a stable-release certification.

| Area | Result | Scope |
| --- | --- | --- |
| Python entry point | Passed | Syntax compilation and headless MainWindow startup |
| GUI language | Passed | Italian/English synchronization, preview notice and demo-only report type |
| Branding | Passed | Logo and all three illustrations load; screenshots updated |
| R scripts | Passed | Parsing of public reporter and existing DADA2 script |
| R dependencies | Passed | Required public report/pipeline namespaces available locally |
| Demo report | Passed | Synthetic sample produces Italian and English DOCX, plots and XLSX |
| Report integration | Passed | Two samples, unclassified genus handling, read totals, relative-abundance totals, three isolated demo mappings |
| Rejected inputs | Passed | Negative counts, zero-total counts and mismatched anamnesis code fail before writing reports |
| Resource portability | Passed | Integration test invokes the report from a temporary working directory |
| Public resources | Passed | Full curated workbook, reference-percentile workbook, original reporter, extended templates and old full outputs excluded from export |
| DADA2 preservation | Passed | Processing script byte-for-byte equal to the pre-separation private snapshot |
| Real FASTQ workflow | Not tested | Needs documented input, external taxonomy databases and result review |
| Database variants | Not tested end to end | SILVA/RDP/Greengenes/GTDB paths need verification with chosen reference files |
| PyInstaller distribution | Not tested | Configuration included; runtime R remains external |
| Other platforms | Not tested | Local checks used Ubuntu; no cross-platform guarantee |

## Reproduce checks

From the repository root after installing dependencies:

```bash
PYTHONPYCACHEPREFIX=/tmp/irisbiome-pycache python3 -m py_compile IrisBiome.py
Rscript -e 'invisible(parse("R/dada2_analysis.R")); invisible(parse("R/report.R"))'
Rscript tests/smoke_report.R
```

Use the [demo command](../README.md#demo-dataset) with `--language en` and `--language it` to generate single-sample reports. The integration script calls the actual CLI with temporary input and output directories; it does not need FASTQ files or taxonomy databases.

Local R versions at verification: R 4.3.3, dada2 1.30.0, officer 0.6.4, flextable 0.9.4, openxlsx 4.2.9, vegan 2.7.6. These are a record of this environment, not a dependency lockfile.

The full-format renderer uses literal `xx–xx` reference intervals. Functional presentation scores come from an independent synthetic fixture, with a guard against displaying them for other inputs. The public reporter uses demonstration-only mappings. A successful run does not validate biological associations, clinical thresholds or nutritional recommendations; those are absent from this build.

Full-format showcase checks: Italian and English DOCX generation, PDF export through LibreOffice, visual inspection of the cover and functional table, literal `xx–xx` references in DOCX/XLSX/PDF, and blocking of synthetic functional scores when demo counts or taxonomy change. The source reference PDF is not included.
