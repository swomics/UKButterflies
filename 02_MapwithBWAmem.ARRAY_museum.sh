#!/bin/bash
#SBATCH -D ./
#SBATCH --export=ALL
#SBATCH -t 72:00:00
#SBATCH --mem=16G
#SBATCH -N 1 -n 1
#SBATCH -a 1-$(find ./01a_museum_cutadapt_reads/ -maxdepth 1 -name "*R1*.fastq*" | wc -l | cut -f1 -d" ")
#SBATCH -o bwa_out.log

#Define variables

RefSeq=Polyommatus_bellargus_Red_MESPA.fasta
total_files=`find ./01a_museum_cutadapt_reads/ -name '*.fastq.gz' | wc -l`
#It is more efficient to run this hashed code in local directory before submitting to queue
#ls 01a_museum_cutadapt_reads/*R1*fastq.gz >> R1.museum.names
#sed -i s:01a_museum_cutadapt_reads/::g R1.museum.names
#ls 01a_museum_cutadapt_reads/*R2*fastq.gz >> R2.museum.names
#sed -i s:01a_museum_cutadapt_reads/::g R2.museum.names
#mkdir 02a_museum_mapped


NAME1=$(sed "${SLURM_ARRAY_TASK_ID}q;d" R1.museum.names)
NAME2=$(sed "${SLURM_ARRAY_TASK_ID}q;d" R2.museum.names)

echo "mapping started" >> map.log
echo "---------------" >> map.log

##Check if Ref Genome is indexed by bwa
if [[ ! RefGenome/$RefSeq.fai ]]
then 
	echo $RefSeq" not indexed. Indexing now"
	bwa index RefGenome/$RefSeq
else
	echo $RefSeq" indexed"
fi


##Map with BWA MEM and output sorted bam file

sample_name=`echo ${NAME1} | awk -F "_190115" '{print $1}'`
echo "[mapping running for] $sample_name"
printf "\n"
echo "time bwa mem RefGenome/$RefSeq 01a_museum_cutadapt_reads/${NAME1} 01a_museum_cutadapt_reads/${NAME2} | samtools sort -o 02a_museum_mapped/${NAME1}.bam" >> map.log
time bwa mem RefGenome/$RefSeq 01a_museum_cutadapt_reads/${NAME1} 01a_museum_cutadapt_reads/${NAME2} | samtools sort -o 02a_museum_mapped/${NAME1}.bam
