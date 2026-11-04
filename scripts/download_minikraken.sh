#!/bin/bash
# Pre-download the minikraken2 database, for when you would rather not do it
# inside a pipeline run. Point --kraken_db at the resulting directory.
#
# The pipeline's dlkraken process does the same thing automatically when
# --kraken_db is null.
set -euo pipefail

url="ftp://ftp.ccb.jhu.edu/pub/data/kraken2_dbs/minikraken_8GB_202003.tgz"
dest="${1:-.}"

mkdir -p "$dest"
cd "$dest"
wget -O minikraken_8GB_202003.tgz "$url"
tar -xvzf minikraken_8GB_202003.tgz
rm minikraken_8GB_202003.tgz

echo "Database extracted to $(pwd)/minikraken_8GB_20200312"
