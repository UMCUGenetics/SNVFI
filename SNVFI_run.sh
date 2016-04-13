#Config file containing paths to tools
config=$1
#Ini file for this specific filtering run
ini=$2

#echo $config
#echo $ini


#Load parameters
source $config
source $ini

##########################Check parameters in config##################################

if [ ! -d "$ROOT" ]; then
    printf "Installation directory '$ROOT' specified as ROOT in $config not found!\n"
    exit 1
fi
if [ ! -f "$BIOVCF" ]; then
    printf "Path to biovcf '$BIOVCF' specified as BIOVCF in $config not found or empty!\n"
    exit 1
fi
if [ ! -d "$TABIX" ]; then
    printf "Tabix directory '$TABIX' specified as TABIX in $config not found or empty!\n"
    exit 1
fi
if [ ! -d "$VCFTOOLS" ]; then
    printf "Path to vcftools binaries '$VCFTOOLS' specified as VCFTOOLS in $config not found or empty!\n"
    exit 1
fi
if [ ! -f "$RSCRIPT" ]; then
    printf "Filtering rscript '$RSCRIPT' specified as RSCRIPT in $config not found or empty!\n"
    exit 1
fi

if [ ! "$MAX_THREADS" ]; then
    printf "Maximum threads specified as MAX_THREADS in $config not found or empty!\n"
fi


###########################Check parameters in ini###################################
if [ ! -f $SNV ]; then
    printf "VCF file '$SNV' specified as SNV in $ini not found or empty!\n"
    exit 1
fi
if [ ! $REF ]; then
    printf "No REF column specified in $ini!\n"
    exit 1
fi
if [ ! $SUB ]; then
    printf "No SUB column specified in $ini!\n"
    exit 1
fi
if [ ! -d "$OUT_DIR" ]; then
    printf "Output directory '$OUT_DIR' specified as OUT_DIR in $ini not found or empty!\n"
    exit 1
fi

if [ ! "$BLACKLIST" ]; then

    printf "No blacklist vcf's found. Specified as BLACKLIST array in $ini!\n"
    exit 1
else
    for vcf in "${BLACKLIST[@]}";
    do
	if [ ! -f $vcf ]; then
	    printf "Blacklist vcf $vcf doesn't exist!\n"
	fi
    done
fi


if [ ! $QUAL ]; then
    printf "Minimum Quality score specified as QUAL in $ini not found!\n"
    exit 1
fi
if [ ! $COV ]; then
    printf "Minimum Quality score specified as COV in $ini not found!\n"
    exit 1
fi

if [ ! $MAIL ]; then
    printf "Mail adress specified as MAIL in $ini not found!\n"
    exit 1
fi


printf "Running filtering with the following settings:\n"
printf "\tBIOVCF : $BIOVCF\n"
printf "\tTABIX : $TABIX\n"
printf "\tVCFTOOLS : $VCFTOOLS\n"
printf "\tRSCRIPT : $RSCRIPT\n"
printf "\tMAX_THREADS : $MAX_THREADS\n"

printf "\tSNV : $SNV\n"
printf "\tREF : $REF\n"
printf "\tSUB : $SUB\n"
printf "\tOUT_DIR : $OUT_DIR\n"
printf "\tBLACKLIST :\n"

for vcf in "${BLACKLIST[@]}";
do
    printf "\t\t$vcf\n"
done

printf "\tQUAL : $QUAL\n"
printf "\tCOV : $COV\n"
printf "\tMAIL : $MAIL\n"

#Create job script

JOB_ID=SNVFI_Filtering_`date | md5sum | cut -d' ' -f1`
JOB_LOG=$OUT_DIR/$JOB_ID.log
JOB_ERR=$OUT_DIR/$JOB_ID.err
JOB_SCRIPT=$OUT_DIR/$JOB_ID.sh

echo "$ROOT/SNVFI_filtering.sh $config $ini" >> $JOB_SCRIPT

qsub -q all.q -P cog_bioinf -pe threaded $MAX_THREADS -l h_rt=2:0:0 -l h_vmem=10G -N $JOB_ID -e $JOB_ERR -o $JOB_LOG -m a -M $MAIL $JOB_SCRIPT




