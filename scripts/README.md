# scripts/

Manual helper scripts, run by hand rather than by the pipeline.

These deliberately live outside `bin/`: Nextflow stages everything in `bin/` onto
the PATH of every task, so the pipeline's own scripts belong there and one-off
utilities do not.

| Script | Purpose |
|---|---|
| `download_minikraken.sh` | Pre-download the minikraken2 database. The `dlkraken` process does this automatically when `--kraken_db` is null. |
| `bracken_alone.sh` | Re-run Bracken across taxonomic levels against existing Kraken reports. Edit the paths at the top before use. |
| `QC_summary_stats.py` | Summarise read counts and lengths from fastq.gz files. |
