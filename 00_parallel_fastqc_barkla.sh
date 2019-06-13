#!/bin/bash

# (c) Romain Villoutreix
# romain.villoutreix@gmail.com
# Last modified: 06/10/2018 

# Description:
# Given an input directory with raw fastq files (gzip and bzip2 compression allowed)
# it will produce the fastqc analysis

# Changelog
#
#QUEUE depreciated
#Look into core options

VERSION='1.1-2018.10.06'
CMD="fastqc"

# Default values for optional variables
EXTRA=''
NOEXTRACT='yes'
NCORES=1
HRS=8
MEM=4

function author {
	echo
	echo "#########################################"
	echo "  $(basename $0)"
	echo "  version $VERSION"
	echo "  (c) Romain Villoutreix"
	echo "  romain.villoutreix@gmail.com"
	echo "#########################################"
	echo
}

function usage {
	echo
	echo "Usage:"
	echo "  $(basename $0)"
	echo "      -i <input directory> => Folder with fastq files (.gz accepted)"
	echo "      -o <output directory> => Output folder to save fastQC reports"
	echo "      -n <number of processors> => processors per library, (max 40)"
	echo "      -t <allocated time> => Allocated time (in hours) for each analysis, (max 72)"
	echo "      -m <allocated memory> => Allocated memory (in gigabytes) for each analysis (max 384)"
	echo "      -h => show this help"
	echo ""
	echo "  Example:"
	echo "      $(basename $0) -i raw_reads -o initial_fastqc"
	echo ""
	echo ""
	exit 0
}

author

if [ "$#" -ge "2" ]; # min 2 args: 1 for -i <input directory>, 1 for -o <output directory>
then 
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|-help) usage
					  ;;
			-i)	shift
				INDIR=$(readlink -f $1)
				;;
			-o)	shift
				OUTDIR=$(readlink -f $1)
				;;
			-n)shift
				NCORES=$1
				;;
			-t)	shift
				HRS=$1
				;;
			-m)	shift
				MEM=$1
				;;
			*)	echo 
				echo "ERROR - Invalid option: $1"
				echo
				usage
				;;
		esac
		shift
	done
else
	usage
fi

if [[ $HRS >72];
then
	echo "ERROR - Exceeded Barkla time limit"
	exit
fi

if [[ $MEM >384];
then
	echo "ERROR - Exceeded Barkla single node memory limit"
	exit
fi

if [[ $NCORES >40];
then
	echo "ERROR - Exceeded Barkla single node core limit"
	exit
fi

N=$(find $INDIR -maxdepth 1 -name "*.fastq*" | wc -l | cut -f1 -d" ")

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TMPDIR="parallel_fastqc_"$TIMESTAMP"_"$RANDOM

INPUT_LOCALDIR="~/sharedscratch/$TMPDIR""_in"


SMSJOB="$OUTDIR/parallel_fastqc.$TIMESTAMP.smsjob.sh"
LOG="$OUTDIR/parallel_fastqc.$TIMESTAMP.smsjob.log"

# Initialize submission script
mkdir -p $OUTDIR
echo '#!/bin/bash -l' > $SMSJOB

# SLURM OPTIONS
# -----------------------------------------
echo '#SBATCH -D '$TMPDIR >> $SMSJOB
echo '#SBATCH --export=ALL' >> $SMSJOB
echo '#SBATCH -t '$HRS':00:00' >> $SMSJOB
echo '#SBATCH --mem="$MEM"G' >> $SMSJOB
echo '#SBATCH -N 1 -n "$NCORES"' >> $SMSJOB
echo '#SBATCH -a 1-'$N >> $SMSJOB
echo '#SBATCH -o '$LOG >> $SMSJOB
# -----------------------------------------

cat >> $SMSJOB <<EOF

#module load apps/fastqc-0.11.5 

INDIR=$INDIR
OUTDIR=$OUTDIR
FQFILES=(\$INDIR/*.fastq*)
#INDEX=\$((SGE_TASK_ID-1))
#INDEX=\$((PBS_ARRAYID-1))
INDEX=\$(($SLURM_ARRAY_TASK_ID-1))
FQ=\${FQFILES[\$INDEX]}
EOF

cat >> $SMSJOB <<EOF

INPUT_TMPDIR=$INPUT_LOCALDIR

# Create temporary local directories
if [ ! -e \$INPUT_TMPDIR ];
then
	mkdir -p \$INPUT_TMPDIR
fi

# copy to local temporary directory
cp \$FQ \$INPUT_TMPDIR/
FQ=\$(basename \$FQ)
EOF

cat >> $SMSJOB <<EOF

LOG="\$OUTDIR/"\${FQ%%.*}".log"

echo "fastQC \$FQ file..." > \$LOG
echo >> \$LOG 
echo "CMD: " >> \$LOG
echo "$CMD \\\">> \$LOG
echo "\$FQ \\\">> \$LOG
EOF

cat >> $SMSJOB <<EOF
echo "-o \$OUTDIR \\\" >> \$LOG
echo "-N $NCORES \\\" >> \$LOG
echo "--no-extract \\\" >> \$LOG
echo >> \$LOG
echo "---------------------------------------------------" >> \$LOG
echo >> \$LOG

cd \$INPUT_TMPDIR

$CMD \\
\$FQ \\
EOF

cat >> $SMSJOB <<EOF
-o \$OUTDIR \\
-t $NCORES \\
--no-extract \\
>> \$LOG 2>&1

#remove temporary files
rm -f \$INPUT_TMPDIR/\$FQ


EOF

chmod +x $SMSJOB


echo "Command to submit the job to Barkla ($QUEUE queue):"
echo
echo "sbatch $SMSJOB"
echo
