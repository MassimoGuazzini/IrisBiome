# Limitations

## Development status

Version `0.9.0.dev0` is a portfolio preview. A working synthetic report does not establish end-to-end pipeline correctness, clinical validity or production readiness. The full DADA2 workflow has not yet been verified here using real paired-end FASTQ data and external taxonomic references.

## Public and private reporting

The public reporter preserves the GUI input interface, descriptive abundance tables, genus-level rarefaction, metadata matching and DOCX/XLSX export. It replaces the original interpretation system with exactly three arbitrary demo mappings. These do not represent biological functions.

The public repository excludes the curated functional knowledge base, reference-percentile workbook, extended literature bibliography, interpretation thresholds and personalized recommendation rules. Previous full demo reports have been replaced so they do not disclose those resources. The private original was preserved outside this repository before editing.

The complete version can be discussed by contacting [Massimo Guazzini](https://github.com/MassimoGuazzini). No clinical validation is claimed for either version.

## Language coverage

The GUI supports Italian and English for anamnesis and synchronizes the report language. Both public reports use equivalent full-format showcase content; taxonomy labels, identifiers and user-entered free text are not translated. The original private English report contained shortened advice and skipped Italian templates; it was not a complete translation of the Italian interpretation layer.

## Scientific scope

- The abundance demo and anamnesis are synthetic, not real patients or a reference population.
- Read counts and 16S taxonomy do not establish actual metabolic activity.
- Rarefaction uses classified genus counts; unclassified reads are excluded and the result is not ASV richness.
- All provided counts are summarized without applying the private filtering or interpretation rules.
- No health-state classification, clinical percentile assessment, enterotype interpretation or personalized nutritional advice is performed by the public reporter.
- A microbiome-state icon illustrates a fictional scenario; it is not a health classification of the input.
- The full-format showcase restores presentation sections, not the private decision engine. Synthetic functional values and evaluation labels are independent of the taxa and appear only when the input exactly matches the shipped demo fixture. Other inputs receive `xx`/withheld values.
- Reference columns contain the literal string `xx–xx`; numeric bounds are not loaded, stored or embedded in documents.

## Operational limits

- Taxonomic references, raw FASTQ data and R are not bundled.
- Large analyses can require substantial CPU, memory and disk space.
- SILVA is selected by default; RDP, Greengenes and GTDB code paths need validation against appropriate external files.
- The report requires integer, non-negative counts with a positive total for every sample and matching JSON metadata.
- Output paths and XLSX columns differ from the private implementation.
- The PyInstaller configuration is supplied but redistributable builds and other operating systems have not been tested.
