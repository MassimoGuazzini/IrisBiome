# Roadmap

## Before a stable release

- Validate paired-end file matching, QC, trimming, ASV inference, merging and chimera removal on a small documented real dataset.
- Verify read-tracking totals and taxonomic output with the selected external database release.
- Test the generated abundance table through the GUI and public reporter.
- Record input provenance, software/database versions, CPU/RAM and expected outputs.
- Test failure handling and packaged resource loading on supported platforms.

## Portfolio improvements

- Pin a reproducible R environment after validating the complete workflow.
- Add automated smoke checks in CI using the synthetic abundance fixture.
- Improve GUI-wide language coverage and document remaining untranslated free text.
- Document database-specific setup against versions actually tested.

Private knowledge-base access and clinical validation are separate from the public software roadmap.
