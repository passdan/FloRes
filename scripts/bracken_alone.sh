#!/bin/bash

krakendb="/scratch/scw2028/host_genomes/kraken_pfp"
readlen=150
kraken_report_folder="/scratch/scw2312/farms/farms/outputs/MicrobiomeAnalysis/Kraken/standard_report/"
levels=("R1" "R2" "R3" "K" "P" "C" "O" "F" "G" "S")


mkdir -p bracken_outputs/samples

find "$kraken_report_folder" -name "*.report" | while read file
do
    sample_id=$(basename $file .kraken.report)
    echo "Processing sample $sample_id"
    
    for level in "${levels[@]}"
	do
	  echo "Processing $sample_id - $level"
	      bracken \
	        -d ${krakendb} \
        	-r ${readlen} \
	        -i ${file} \
	        -l ${level} \
	        -o bracken_outputs/samples/${sample_id}_${level}.bracken.tsv
	done
done


for level in ${levels[@]}
do
	echo "compiling level $level into analytic matrix"
	${PYTHON3} /opt/conda/bin/combine_bracken_outputs.py --files bracken_outputs/samples/*$level.bracken.tsv -o bracken_outputs/bracken_analytic_matrix_${level}.csv
done
