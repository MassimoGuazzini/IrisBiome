# Installation

These instructions target Ubuntu 24.04.

## System Packages

Install R, build tools and native libraries used by R graphics/reporting packages:

```bash
sudo apt update
sudo apt install r-base r-base-dev pkg-config libfontconfig1-dev libfreetype6-dev libcairo2-dev libpng-dev
```

Install packaged Bioconductor dependencies where available:

```bash
sudo apt install r-bioc-dada2 r-bioc-shortread r-bioc-biostrings r-bioc-genomeinfodb r-bioc-rhtslib r-cran-rcppparallel
```

## Python

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## R

```bash
Rscript R/install_dependencies.R
```

Verify the core packages:

```bash
Rscript -e "library(dada2); library(ShortRead); library(Biostrings); library(officer); library(flextable); library(openxlsx); cat('OK\n')"
```

## Taxonomy Databases

Taxonomy databases are not included. Put them in `database/`, select the folder in the GUI, or set:

```bash
export IRISBIOME_DB_DIR=/path/to/database
```

See [../database/README.md](../database/README.md).


Set `IRISBIOME_DB_DIR` for the external taxonomy database; the legacy `FAUSTBIOME_DB_DIR` remains a fallback. The public reporter checks dependencies and never installs them automatically.
