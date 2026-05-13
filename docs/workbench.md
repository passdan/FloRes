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

Edit `wb/config/wb.env` and set the user-defined variables:
- `GCS_BUCKET`: Your Workbench GCS bucket resource ID (e.g., `nf-output`)
- `GCS_REF_BUCKET`: Bucket containing reference genomes (e.g., `referencegenomes-wb-my-workspace-1234`)
- `GCS_BUCKET_LOCATION`: Region (default: `us-central1`)
- `GOOGLE_ARTIFACT_REPO`: Your artifact registry repo (e.g., `nextflow-containers`)

**Note**: Project IDs, service accounts, and registry paths are automatically determined from your `gcloud` and `wb` CLI configurations.

Then run:

```bash
# Set up infrastructure (creates buckets, service accounts, etc.)
./wb/setup_infra.sh wb

# Upload input data and reference databases to GCS
./wb/upload_data.sh wb

# Build Docker image and push to Artifact Registry
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
conda env create -f envs/AMR++_env.yaml
conda activate AMR++_env

# Verify Nextflow version 24 is installed
nextflow -v

# Run the test pipeline (takes ~5 minutes)
nextflow run main_AMR++.nf
```

Expected output: results in `~/repos/FloRes/test_results`

---

## Configuration

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
