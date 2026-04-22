#!/usr/bin/env bash
set -euo pipefail

# ========================================
# GTDB-Tk native runner for macOS
# AUTO-detects .fa, .fasta, .fna files
# ========================================

if [[ $# -ne 2 ]]; then
  cat <<'EOF2'
Usage:
  bash run_gtdbtk_fork_and_make_table_v3.sh <genome_dir> <out_dir>

Arguments:
  <genome_dir>   Directory containing genome FASTA files
  <out_dir>      Output directory for GTDB-Tk results

Example:
  bash run_gtdbtk_fork_and_make_table_v3.sh \
    /Users/gmboowa/SRR9703249 \
    /Users/gmboowa/test_gtdbtk252_py310_fork_identify
EOF2
  exit 1
fi

GENOME_DIR="$1"
OUT_DIR="$2"

ENV_PY="/Users/gmboowa/mambaforge/envs/gtdbtk252_py310/bin/python"
ENV_BIN="/Users/gmboowa/mambaforge/envs/gtdbtk252_py310/bin"
GTDBTK_DATA_PATH_DEFAULT="/Volumes/AfricaPGI/gtdbtk_db/release226"

export GTDBTK_DATA_PATH="${GTDBTK_DATA_PATH:-$GTDBTK_DATA_PATH_DEFAULT}"
export PATH="$PATH:$ENV_BIN"

if [[ ! -d "$GENOME_DIR" ]]; then
  echo "ERROR: genome directory does not exist: $GENOME_DIR" >&2
  exit 1
fi

if [[ ! -x "$ENV_PY" ]]; then
  echo "ERROR: Python executable not found: $ENV_PY" >&2
  exit 1
fi

if [[ ! -d "$GTDBTK_DATA_PATH" ]]; then
  echo "ERROR: GTDBTK_DATA_PATH does not exist: $GTDBTK_DATA_PATH" >&2
  exit 1
fi

# ========================================
# Detect supported FASTA files
# ========================================
shopt -s nullglob

FILES=(
  "$GENOME_DIR"/*.fa
  "$GENOME_DIR"/*.fasta
  "$GENOME_DIR"/*.fna
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: no .fa/.fasta/.fna files found in $GENOME_DIR" >&2
  exit 1
fi

echo "[INFO] Detected ${#FILES[@]} genome files:"
for f in "${FILES[@]}"; do
  echo "  - $(basename "$f")"
done

# Determine extension dynamically (use first file)
FIRST_FILE="${FILES[0]}"
EXTENSION="${FIRST_FILE##*.}"

echo "[INFO] Using extension: $EXTENSION"

shopt -u nullglob

mkdir -p "$OUT_DIR"

echo "========================================"
echo "GTDB-Tk native fork runner"
echo "Genome dir:       $GENOME_DIR"
echo "Detected ext:     $EXTENSION"
echo "Output dir:       $OUT_DIR"
echo "GTDBTK_DATA_PATH: $GTDBTK_DATA_PATH"
echo "Python env:       $ENV_PY"
echo "========================================"

run_gtdbtk() {
  "$ENV_PY" - "$@" <<'PY'
import multiprocessing as mp
try:
    mp.set_start_method("fork", force=True)
except RuntimeError:
    pass

from gtdbtk.__main__ import main
main()
PY
}

echo "[1/4] Running GTDB-Tk identify..."
run_gtdbtk identify \
  --genome_dir "$GENOME_DIR" \
  --out_dir "$OUT_DIR" \
  --extension "$EXTENSION" \
  --cpus 1

echo "[2/4] Running GTDB-Tk align..."
run_gtdbtk align \
  --identify_dir "$OUT_DIR" \
  --out_dir "$OUT_DIR" \
  --cpus 1

USER_MSA_GZ="$OUT_DIR/align/gtdbtk.bac120.user_msa.fasta.gz"
if [[ ! -f "$USER_MSA_GZ" ]]; then
  echo "ERROR: expected MSA file not found: $USER_MSA_GZ" >&2
  exit 1
fi

echo "[check] Validating gzip integrity..."
gunzip -t "$USER_MSA_GZ"

echo "[3/4] Running GTDB-Tk classify..."
run_gtdbtk classify \
  --genome_dir "$GENOME_DIR" \
  --align_dir "$OUT_DIR" \
  --out_dir "$OUT_DIR" \
  --extension "$EXTENSION" \
  --skip_ani_screen \
  --pplacer_cpus 1 \
  --cpus 1 \
  --scratch_dir /tmp

echo "[4/4] Extracting summary table..."

SUMMARY_TSV="$OUT_DIR/classify/gtdbtk.bac120.summary.tsv"
FINAL_TABLE="$OUT_DIR/classify/gtdbtk_summary_table.tsv"

if [[ ! -f "$SUMMARY_TSV" ]]; then
  echo "ERROR: summary TSV not found: $SUMMARY_TSV" >&2
  exit 1
fi

"$ENV_PY" - "$SUMMARY_TSV" "$FINAL_TABLE" <<'PY'
import csv, re, sys
from pathlib import Path

summary_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

def extract_taxon(c, p):
    return next((x[len(p):] for x in c.split(";") if x.strip().startswith(p)), "")

def clean_ref(r):
    m = re.search(r"(GC[AF]_\d+\.\d+)", r or "")
    return m.group(1) if m else r

rows = list(csv.DictReader(open(summary_path), delimiter="\t"))

with open(output_path, "w", newline="") as out:
    writer = csv.DictWriter(out, fieldnames=[
        "Sample ID","Species","Genus","Closest Reference",
        "ANI (%)","Alignment Fraction","Classification Method"
    ], delimiter="\t")
    writer.writeheader()

    for r in rows:
        writer.writerow({
            "Sample ID": r.get("user_genome",""),
            "Species": extract_taxon(r.get("classification",""), "s__"),
            "Genus": extract_taxon(r.get("classification",""), "g__"),
            "Closest Reference": clean_ref(
                r.get("closest_genome_reference") or r.get("closest_placement_reference")
            ),
            "ANI (%)": r.get("closest_genome_ani",""),
            "Alignment Fraction": r.get("closest_genome_af",""),
            "Classification Method": "Topology + ANI"
        })

print(f"Wrote: {output_path}")
PY

echo "Done."
