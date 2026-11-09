# Taxonomic databases

This repository intentionally does not include taxonomic databases.

The DADA2 pipeline expects a database folder with this layout:

```text
database/
  dada2/
    silva/
      silva_old/
        silva_nr_v128_train_set.fa.gz
        silva_species_assignment_v128.fa.gz
    rdp/
      rdp_19_toGenus_trainset.fa.gz
      rdp_19_toSpecies_trainset.fa.gz
    greengenes/
      gg2_2024_09_toGenus_trainset.fa.gz
      gg2_2024_09_toSpecies_trainset.fa.gz
```

You can place the database folder here, choose it in the GUI, or set:

```bash
export IRISBIOME_DB_DIR=/path/to/database
```

Check upstream database licenses before redistributing them.

