#!/bin/bash
#SBATCH --account=scw2312
#SBATCH --partition=highmem       # the requested queue
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=2      #
#SBATCH --mem=8000	     # in megabytes, unless unit explicitly stated
#SBATCH --error=logs/%J.err         # redirect stderr to this file
#SBATCH --output=logs/%J.out        # redirect stdout to this file
##SBATCH --mail-user=email@Cardiff.ac.uk  # email address used for event notification
##SBATCH --mail-type=end                                   # email on job end
##SBATCH --mail-type=fail                                  # email on job failure
 
 
echo "Some Usable Environment Variables:"
echo "================================="
echo "hostname=$(hostname)"
echo \$SLURM_JOB_ID=${SLURM_JOB_ID}
echo \$SLURM_NTASKS=${SLURM_NTASKS}
echo \$SLURM_NTASKS_PER_NODE=${SLURM_NTASKS_PER_NODE}
echo \$SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK}
echo \$SLURM_JOB_CPUS_PER_NODE=${SLURM_JOB_CPUS_PER_NODE}
echo \$SLURM_MEM_PER_NODE=${SLURM_MEM_PER_NODE}

module purge
module load nextflow
module load singularity

export NXF_OPTS="-Xms500M -Xmx2G"

workdir="/scratch/scw2312/farms"
inputdir="/scratch/scw2028/farms/NonHost"
installdir="/scratch/b.dnp24ftx/AMR-local-mod"
run="farms"


nextflow run ${installdir}/main_AMR++.nf \
	-w "${workdir}/${run}/work" \
	-c "${installdir}/config/singularity_slurm.config" \
	--reads "${inputdir}/*{R1,R2}.fastq.gz" \
	--pipeline resistome \
	--output "${workdir}/${run}/outputs" \
	--snp Y \
	-with-report "${workdir}/${run}/${run}-${SLURM_JOB_ID}.html" \
	-with-trace "${installdir}/logs/${run}-${SLURM_JOB_ID}.trace.txt" \
        -resume	

#singularity exec docker://multiqc/multiqc:latest multiqc -o ${workdir}/${run}/${run}-outputs/Results/ ${workdir}/${run}/${run}-outputs

####
# Results copyout
####
#mkdir ${resultsdir}/${run}
#rsync -r ${workdir}/${run}/${run}-outputs/HostRemoval/NonHostFastq ${resultsdir}/$run/
#rsync -r ${workdir}/${run}/${run}-outputs/Results ${resultsdir}/$run/
#rsync ${workdir}/${run}/${run}.html ${resultsdir}/$run/

## Delete all
#rm -rf ${workdir}/${run}
