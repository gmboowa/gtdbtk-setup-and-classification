## GTDB-Tk Setup and Genome Classification Pipeline

This repository provides a complete, reproducible workflow for:

- Installing and configuring GTDB-Tk
- Downloading and preparing the GTDB reference database (release226-compatible)
- Running genome classification
- Generating a clean, publication-ready summary table

---

### Repository Structure

```bash

gtdbtk-setup-and-classification/
│
├── scripts/
│   └── run_gtdbtk_fork_and_make_table_v3.sh
│
├── example_data/
│   └── genomes/
│
├── example_output/
│   └── gtdbtk_summary_table.tsv
│
└── README.md
```
---

### 1. Download the GTDB-Tk Database
```bash

mkdir -p ~/gtdbtk_db
cd ~/gtdbtk_db

wget https://data.ace.uq.edu.au/public/gtdb/data/releases/latest/auxillary_files/gtdbtk_package/full_package/gtdbtk_data.tar.gz
```

---

### 2. Extract the Database
```bash

tar -xvzf gtdbtk_data.tar.gz
mv gtdbtk_data release226
```

Expected structure:
---

~/gtdbtk_db/release226/
├── fastani/
├── markers/
├── metadata/
├── msa/
├── pplacer/
├── radii/
├── taxonomy/

---

### 3. Set Environment Variable

Temporary:
```bash
export GTDBTK_DATA_PATH=~/gtdbtk_db/release226
```

Permanent:
```bash
echo 'export GTDBTK_DATA_PATH=~/gtdbtk_db/release226' >> ~/.zshrc
source ~/.zshrc
```

---

### 4. Verify Installation
```bash


gtdbtk check_install
```


---

### 5. Run the Pipeline

```bash


bash scripts/run_gtdbtk_fork_and_make_table_v3.sh  example_data/genomes  output/
```

---

### 6. Example Output Table

| Sample ID | Species | Genus | Closest Reference | ANI (%) | Alignment Fraction | Classification Method |
|----------|--------|-------|-------------------|--------|-------------------|----------------------|
| Sample_1 | Escherichia coli | Escherichia | GCF_000005845.2 | 99.2 | 0.95 | Topology + ANI |
| Sample_2 | Klebsiella pneumoniae | Klebsiella | GCF_000240185.1 | 98.7 | 0.93 | Topology + ANI |
| Sample_3 | Acinetobacter baumannii | Acinetobacter | GCF_000737145.1 | 97.8 | 0.91 | Topology + ANI |

---

### Summary

This pipeline enables:

- Reliable genome classification using GTDB-Tk  
- Automated processing of genome FASTA files  
- Generation of clean, analysis-ready summary tables  

---


### License

MIT License
