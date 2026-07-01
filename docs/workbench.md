# FloRes on Verily Workbench

**Prerequisites**:
- You must create a Workbench workspace where you have **ADMIN** permissions
- All setup and execution must be done within this workspace

## Dependencies

- **Verily Workbench CLI** (`wb`) - Workbench command-line tool
- **Google Cloud SDK** (`gcloud`) - GCP command-line tool
- **Docker** - For building and pushing container images (must be running)
- **Nextflow v24** - Workflow orchestration (installed in Workbench app)
  - **Note**: v25 has breaking changes and is not compatible with this pipeline

## Quick Start: Workbench Orchestration with Google Batch

This guide walks through setting up and running FloRes with Workbench orchestration and Google Batch compute. The setup is split between local commands (for infrastructure) and Workbench app commands (for execution).

### Step 1: Create Workspace and App

Create a new workspace and app in the Workbench UI (or use the CLI if preferred).

### Step 2: Local Setup

Run these commands on your **local machine**:

```bash
# Set your active workspace (replace with your workspace ID)
wb workspace set --id=your-workspace-id

# Copy the Workbench environment template
cp wb/config/wb.env.template wb/config/wb.env
```

The template has sensible defaults (`nf-data` and `nf-containers`) — edit `wb/config/wb.env` only if you want different resource names. Project IDs, service accounts, and registry paths are automatically determined from your `gcloud` and `wb` CLI configurations.

Then run:

```bash
# Set up infrastructure (creates buckets, service accounts, etc.)
./wb/setup_infra.sh wb

# Upload input data and reference databases to GCS
./wb/upload_data.sh wb

# Build Docker image and push to Artifact Registry (20-30 min, mostly conda)
# NOTE: Docker must be running before executing this command
./wb/build.sh --env wb --push
```

### Step 3: Workbench App Setup

Open your Workbench app, launch the Terminal, and run:

```bash
# Clone the repository
cd repos/ && git clone https://github.com/passdan/FloRes.git && cd FloRes/

# Copy the environment template
cp wb/config/wb.env.template wb/config/wb.env
```

Now copy your local `wb/config/wb.env` configuration into the Workbench app.

### Step 4: Run the Pipeline

```bash
./wb/run.sh --env wb
```

Results will be stored in your configured GCS bucket.

**Known Issues**:
- The `gcloud storage cp` command may not correctly resolve Workbench resource names to full `gs://` paths when running `upload_data.sh` or `run.sh`. If you encounter path resolution issues, manually specify the full GCS bucket path in your `wb.env` configuration.

---

## Running from the Workbench UI

Submit pipeline jobs directly from the Workbench web interface instead of the terminal.

### Step 1: Local Setup

Set your active Workbench workspace and configure the environment:

```bash
wb workspace set --id=<your-workspace-id>
cp wb/config/wb.env.template wb/config/wb.env
```

The template has sensible defaults — edit `wb/config/wb.env` only if you want different resource names.

### Step 2: Create Infrastructure

```bash
./wb/setup_infra_ui.sh
```

This creates the GCS bucket and Artifact Registry repository. All other infrastructure (APIs, VPC, NAT, service accounts, IAM) is managed by Workbench.

### Step 3: Build and Push Container

```bash
./wb/build.sh --env wb --push
```

Docker must be running. This builds the pipeline container and pushes it to Artifact Registry. Expect 20-30 minutes — the conda environment solve is slow.

### Step 4: Upload Data and Pipeline

```bash
./wb/upload_data.sh wb
./wb/upload_pipeline.sh
```

This uploads input data to the bucket and pipeline source code (with workspace-specific configuration automatically resolved from `wb.env`) to `gs://<bucket>/pipeline/`. These can run in parallel with the container build (Step 3).

### Step 5: Add Workflow in Workbench UI

1. Go to **Workflows** in your workspace and add a new workflow from the **workspace bucket**.
2. Select your bucket and enter `pipeline/` as the prefix.
3. Select `main_AMRplusplus.nf` as the workflow source.
4. The display name must **not** contain `+` characters (Workbench rejects them).

### Step 6: Create and Run a Job

1. Create a new job from the workflow.
2. Set the **profile** to `workbench`.
3. Select `params_google_batch.yaml` as the **parameters file**.

### Known Limitations

- The Workbench UI orchestrator runs Nextflow v25, which is stricter than the v24 pinned in the Docker container (used by worker nodes only). Pipeline code must be compatible with both versions.
- SNP verification (`snp: "Y"`) has a known upstream bug (sample name mismatch in `SNP_Verification.py`). Leave it disabled (`snp: "N"` in the params file) until fixed.

---

## Alternative: Quick Demo in Workbench JupyterLab

For a simple demonstration without Google Batch (both orchestration and execution running in the same Workbench app):

Create a new Workbench workspace and add this git repository in the **Apps** tab.

Create a JupyterLab app instance, launch it, and open the terminal:

```bash
# Initialize conda
conda init
source ~/.bashrc

# Navigate to the repository
cd repos/FloRes

# Create and activate the conda environment
conda env create -f envs/AMRplusplus_env.yaml
conda activate AMRplusplus_env

# Verify Nextflow version 24 is installed
nextflow -v

# Run the test pipeline (takes ~5 minutes)
nextflow run main_AMRplusplus.nf
```

Expected output: results in `~/repos/FloRes/test_results`

---

## Configuration

### Reference Databases

The repo bundles small test data (`data/host/chr21.fasta.gz`, MEGARes AMR databases, adapters) that are sufficient for demo runs. Production runs require additional reference databases uploaded to your GCS bucket:

| Resource | Size | Needed for |
|---|---|---|
| Full host genome (e.g., GRCh38) | ~3 GB | Host read removal (`standard_AMR`, `rm_host`) |
| Kraken2 database (e.g., minikraken 8GB) | ~8 GB | Microbiome classification (`*_wKraken*`, `kraken`) |
| QIIME2 Greengenes classifier | ~1 GB | 16S analysis (`qiime2` pipeline only) |

Upload these to your `GCS_REF_BUCKET` and update the paths in `params_google_batch.yaml`. The Kraken2 module will auto-download minikraken if no database is specified, but this does not work on Google Batch workers.

### Resource Scaling on Google Batch

Google Batch does NOT automatically scale machine types based on CPU/memory requests. Resource scaling is configured in `config/google_batch.config`.

Each process that needs more than default resources must explicitly specify a matching `machineType`. Current resource allocations:

| Process | CPUs | Memory | Machine Type |
|---------|------|--------|-------------|
| Default | 4 | 16 GB | n2-standard-4 |
| runqc | 16 | 64 GB | n2-standard-16 |
| bowtie2_align | 32 | 128 GB | n2-standard-32 |
| bowtie2_rm_contaminant_fq | 32 | 256 GB | n2-highmem-32 |
| bwa_align | 16 | 128 GB | n2-highmem-32 |
| runkraken | 16 | 256 GB | n2-highmem-32 |
| runkrakenInterleaved | 16 | 256 GB | n2-highmem-32 |

### Supporting Environments

**Local** (testing): `./wb/run.sh --env local`
- Requires Docker and Conda

**GCP** (debugging): `./wb/run.sh --env gcp`
- For debugging Google Batch jobs with visible logs
- Requires `gcloud` CLI and Docker
