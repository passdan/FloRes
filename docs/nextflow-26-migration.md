# Migrating FloRes to Nextflow 26.04

## Why the pipeline broke

Nextflow 26.04 enables the **strict syntax parser** (v2) by default. The strict
parser is a restricted subset of Groovy defined by the Nextflow language
specification. It was introduced as opt-in in 25.04 (`NXF_SYNTAX_PARSER=v2`) and
became the default in 26.04, so code that ran under the legacy v1 parser can fail
without any change on your side.

Two separate things changed between 24.10 and now:

| Version | Change | Effect on FloRes |
|---|---|---|
| 25.04 | Java 17 or newer required | Pipeline won't start on Java 11 |
| 25.04 | `process shell:` deprecated | Not used here |
| 26.04 | Strict parser on by default | The failures listed below |

If you need to get a run out of the door before migrating, pin the old parser:

```bash
export NXF_SYNTAX_PARSER=v1
```

That escape hatch will disappear when the legacy parser is removed, so treat it as
temporary.

## Changes made, by category

### 1. Statements at script level moved into the entry workflow

Strict syntax forbids mixing executable statements with script declarations. The
old `main.nf` ran `log.info`, built `taxlevel_ch`, created the `fastq_files` and
`bam_files_ch` channels, and declared `def helpMessage` all at file scope.

All of it now lives inside `workflow { }`. The help text became a
`helpMessage()` function, which is still allowed because standalone functions are
supported.

The same pattern appeared in the modules: `bwa.nf` and
`bowtie2-for_AMRplusplus.nf` both opened with

```groovy
if( params.amr ) {
    amr = file(params.amr)
    if( !amr.exists() ) return amr_error(amr)
}
threads = params.threads
deduped = params.deduped
```

Those blocks are gone. File validation now happens once in the entry workflow via
`check_file()` in `modules/functions.nf`, and processes read `params.*` directly or
take values as inputs.

### 2. `workflow.onComplete` moved inside the entry workflow

```groovy
// before — top level
workflow.onComplete { ... }

// after — inside workflow { }
workflow.onComplete = { ... }
```

### 3. `import` declarations removed

`fastq_resistome_bwa.nf`, `fastq_resistome.nf`, `fastq_align.nf` and
`fastq_host_removal.nf` each had `import java.nio.file.Paths`. Import declarations
are not supported; the strict parser wants fully qualified class names.

`Paths.get(params.amr_index)` was only wrapping a path for
`Channel.fromPath`, which accepts the string directly, so the import was dropped
rather than rewritten:

```groovy
// before
Channel.fromPath(Paths.get(params.amr_index)).map { file(it.toString()) }.filter { file(it).exists() }

// after
channel.fromPath(params.amr_index).filter { entry -> entry.exists() }
```

### 4. `addParams` removed from includes

`bam_deduped_resistome.nf` used the restricted include clause:

```groovy
include { runresistome as runresistome_dedup ; ... } from '../modules/Resistome/resistome' addParams(prefix: 'dedup_AMR')
```

The replacement is to pass the value as an explicit input. `runresistome`,
`resistomeresults`, `runsnp` and `snpresults` each gained a `val(prefix)` input,
and the standard and deduplicated runs now call the same `RESISTOME_WF`
subworkflow with different prefixes.

### 5. `script:` label added to every process

Under strict syntax the `script:` label is mandatory in any process that also has
inputs, outputs or directives. It may only be omitted when the process has nothing
else. Most FloRes processes relied on the implicit form, so `script:` was added
throughout — 8 processes in `resistome.nf`, 5 in `kraken_and_bracken.nf`, and the
rest across the alignment and trimming modules.

### 6. Implicit environment variables replaced

The `env { }` config scope defines `PYTHON3`, `BWA`, `SAMTOOLS`, `KRAKEN2`,
`FASTP` and `BOWTIE2`, and process scripts referenced them as `${PYTHON3}`.
Strict syntax removes implicit environment variable resolution in Groovy string
interpolation.

Every one is now escaped so that bash expands it from the task environment, with a
fallback if the `env` scope isn't loaded:

```bash
# before (Groovy interpolation, now rejected)
${PYTHON3} ${baseDir}/bin/amr_long_to_wide.py ...

# after (bash expansion, with default)
${PYTHON3:-python3} ${projectDir}/bin/amr_long_to_wide.py ...
```

### 7. Command line values are no longer coerced to booleans

This one is quiet and dangerous. The strict parser does not convert command line
values to booleans or numbers, so `--kraken false` arrives as the **string**
`"false"`, which is truthy. Every `if( params.someFlag )` would have silently
inverted.

`modules/functions.nf` now provides `as_bool()`, which accepts
`true/false/y/n/yes/no/1/0` and errors on anything else. Every boolean parameter is
read through it. If you add a new boolean parameter, route it through `as_bool()`
too.

### 8. Assignment inside an expression split out

`fastq_microbiome_wBracken.nf` had:

```groovy
def combined_ch = runkraken.out.bracken_input.combine(taxlevel_ch).set { combined_input_ch }
```

`set` returns nothing, so this assigned null and relied on the side effect.
Assignments inside expressions are removed syntax. Now:

```groovy
bracken_input_ch = runkraken.out.bracken_input.combine(taxlevel_ch)
```

### 9. Configuration file restrictions

Strict config syntax allows only config assignments, config blocks and includes at
the top level, and only `params` may be referenced as variables.

`params_google_batch.config` opened with two top-level `def` declarations:

```groovy
def gcs_bucket = System.getenv("GCS_BUCKET") ?: "nf-files"
def gcs_ref_bucket = System.getenv("GCS_REF_BUCKET") ?: gcs_bucket
```

Both are now params, referenced as `params.gcs_bucket`:

```groovy
params {
    gcs_bucket = System.getenv("GCS_BUCKET") ?: "nf-files"
    gcs_ref_bucket = System.getenv("GCS_REF_BUCKET") ?: params.gcs_bucket
    reads = "gs://${params.gcs_bucket}/data/raw/*_R{1,2}.fastq.gz"
}
```

`nextflow.config` also had a stray top-level `profile = "local"`, which did nothing
and is gone.

### 10. `params` set inside `process` scope

`params.config` assigned params from within process selectors:

```groovy
withName: 'runqc' {
    cpus = {16}
    params.threads = 16    // removed
    memory = "24.GB"
}
```

Setting params from the process scope is not valid config. The `params.threads`
assignments are removed and processes use `task.cpus`, which is what the scripts
already passed to the tools. The now-unused `threads` param is gone.

### 11. `queueSize` moved to the executor scope

`queueSize` was set inside `process { }` in `params.config`,
`config/conda_slurm.config`, `config/local_slurm.config`,
`config/singularity_slurm.config` and `config/apptainer_slurm.config`. It belongs
in `executor { }` and was silently ignored where it sat.

### 12. Deprecations cleared

These still work but warn, and will become errors:

- `Channel.of` / `Channel.fromPath` → `channel.of` / `channel.fromPath`
- implicit closure parameter `it` → named parameters, e.g. `.map { entry -> ... }`
- `exit 1` inside `.ifEmpty { }` → `error`
- `baseDir` → `projectDir`
- `process when:` in `bam2fq.nf` → the conditional moved into the calling workflow

## Verifying

```bash
nextflow lint main.nf
nextflow run . -preview --pipeline standard --reads "data/raw/*_R{1,2}.fastq.gz"
```

`nextflow lint` was added in 25.04 and checks scripts and config files with the
strict parser, so it catches these problems without a run. Worth adding to CI.

## Separately fixed while migrating

Pre-existing bugs, unrelated to the parser:

- `modules/Microbiome/kraken2.nf` had `process runkraken {:` — a stray colon that
  made the file unparseable. The file was a dead duplicate of
  `kraken_and_bracken.nf` and was deleted, along with its
  `bin/kraken2_long_to_wide.py`.
- `main.nf` printed "You didn't provide any fastq or bam files as input" whenever
  input *was* provided: the condition was inverted and used a single `|`. Replaced
  with per-pipeline validation.
- `bowtie2_align` had Groovy `//` comments inside a bash script block for the
  `deduped == "Y"` branch, which bash would have tried to execute. Bowtie2 never
  supported dedup, so that branch is removed; use bwa for deduplicated counts.
- `bwa_align`'s dedup branch wrote a SAM, converted it, then ran
  `samtools view -h -o ...dedup.sam` and immediately deleted the output. It also
  used `samtools rmdup`, which upstream deprecated. Rewritten around
  `samtools markdup` with no intermediate SAM. **This changes deduplicated counts
  slightly** — `markdup` and `rmdup` do not pick identical representative reads.
- `runkrakenInterleaved` passed `--fastq-input`, which is a Kraken 1 flag that
  Kraken 2 rejects. The interleaved and paired processes are now one `runkraken`
  that chooses its arguments from the number of input files.
