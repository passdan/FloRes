#!/bin/bash
#SBATCH --account=scwf00056_r_silvester_54
#SBATCH --qos=maxjobs100
#SBATCH --partition=highmem       # the requested queue
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4      #
#SBATCH --mem=8000	     # in megabytes, unless unit explicitly stated
#SBATCH --error=logs/%J.err         # redirect stderr to this file
#SBATCH --output=logs/%J.out        # redirect stdout to this file
 
 
echo "Some Usable Environment Variables:"
echo "================================="
echo "hostname=$(hostname)"
echo \$SLURM_JOB_ID=${SLURM_JOB_ID}
echo \$SLURM_NTASKS=${SLURM_NTASKS}
echo \$SLURM_NTASKS_PER_NODE=${SLURM_NTASKS_PER_NODE}
echo \$SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK}
echo \$SLURM_JOB_CPUS_PER_NODE=${SLURM_JOB_CPUS_PER_NODE}
echo \$SLURM_MEM_PER_NODE=${SLURM_MEM_PER_NODE}

module load Java/21.0.8

export NXF_OPTS="-Xms500M -Xmx2G"

workdir="/scratch/SCWF00056/legacydata/scw2028"
installdir="/scratch/SCWF00056/legacydata/b.dnp24ftx/AMR-local-mod"
run="MOD"


./nextflow-24.10.9-dist run ${installdir}/main_AMR++.nf \
	-w "${workdir}/${run}/work" \
	-c "${installdir}/config/apptainer_slurm.config" \
	--reads "${workdir}/${run}/fastqs/*{_1,_2}.fq.gz" \
	--pipeline standard_AMR_wKraken_and_Bracken \
	--output "${workdir}/${run}/outputs" \
	--snp Y \
	-with-report "${workdir}/${run}/logs/${run}-${SLURM_JOB_ID}.html" \
	-with-trace "${workdir}/${run}/logs/${run}-${SLURM_JOB_ID}.trace.txt" \
        -resume	

#singularity exec docker://multiqc/multiqc:latest multiqc -o ${workdir}/${run}/${run}-outputs/Results/ ${workdir}/${run}/${run}-outputs

## Delete all
#rm -rf ${workdir}/${run}
