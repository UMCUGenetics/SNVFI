#Config file containing paths to tools
runtime_config=$1
#Ini file for this specific filtering run
runtime_settings=$2

#Load parameters
source $runtime_config
source $runtime_settings

######################Check parameters in config##############################


if [ ! -d "$SNVFI_ROOT" ]; then
    SNVFI_ROOT=`dirname $0`

    if [ $SNVFI_ROOT == "." ]; then
        SNVFI_ROOT=`pwd`
    fi

    printf "Using $SNVFI_ROOT as SNVFI_ROOT\n"
    printf "Please set SNVFI_ROOT=<path/to/this/script> in $runtime_config "
    printf "in the future.\n"
fi
if [ ! "$MAXIMUM_THREADS" ]; then
    printf "Maximum threads specified as MAXIMUM_THREADS in $runtime_settings "
    printf "not found or empty.  Setting to 1.\n"
    MAXIMUM_THREADS=1
fi
if [ ! "$USE_SGE" ]; then
    printf "Assuming we do not use the Sun Grid Engine.  "
    printf "Put \"USE_SGE=YES\" in your config file to enable.\n"
    USE_SGE=NO
fi


#######################Check parameters in ini##############################
if [ ! -f $SNV ]; then
    printf "VCF file '$SNV' specified as SNV in $runtime_settings not found "
    printf "or empty!\n"
    exit 1
fi
if [ ! $CONTROL ]; then
    printf "No CONTROL column specified in $runtime_settings!\n"
    exit 1
fi
if [ ! $SUBJECT ]; then
    printf "No SUBJECT column specified in $runtime_settings!\n"
    exit 1
fi
if [ ! -d "$OUTPUT_DIRECTORY" ]; then
    printf "Output directory '$OUT_DIR' specified as OUTPUT_DIRECTORY in "
    printf "$runtime_settings not found or empty!\n"
    exit 1
fi

if [ ! "$BLACKLIST" ]; then

    printf "No blacklist vcf's found. Specified as BLACKLIST array in "
    printf "$runtime_settings!\n"
    exit 1
else
    for vcf in "${BLACKLIST[@]}";
    do
	if [ ! -f $vcf ]; then
	    printf "Blacklist vcf $vcf doesn't exist!\n"
	fi
    done
fi


if [ ! $MINIMUM_QUALITY ]; then
    printf "Minimum Quality score specified as MINIMUM_QUALITY in "
    printf "$runtime_settings not found!\n"
    exit 1
fi
if [ ! $MINIMUM_COVERAGE ]; then
    printf "Minimum Quality score specified as MINIMUM_COVERAGE in "
    printf "$runtime_settings not found!\n"
    exit 1
fi
if [ ! $MINIMUM_VAF ]; then
    printf "VAF specified as MINIMUM_VAF in $runtime_settings not found!\n"
    exit 1
fi

if [ $USE_SGE == "YES" ] && [ ! $MAIL ]; then
    printf "You indicated to use the Sun Grid Engine, but you haven't set an "
    printf "e-mail address.  Please add MAIL=<your@address.tld> to "
    printf "$runtime_settings"
    exit 1
fi

if [ ! $CLEANUP ]; then
    printf "Assuming we do not clean up after a succesful run."
    printf "Please specify if you want to clean up in-between files.  "
    printf "Put \"CLEANUP=YES\" in $runtime_settings to clean up next time.\n"
    CLEANUP=NO
fi

printf "Running filtering with the following settings:\n"
printf "\tPATH            : $PATH\n"
printf "\tMAXIMUM_THREADS : $MAXIMUM_THREADS\n"
printf "\tSNV             : $SNV\n"
printf "\tCONTROL         : $CONTROL\n"
printf "\tSUBJECT         : $SUBJECT\n"
printf "\tOUT_DIR         : $OUT_DIR\n"
printf "\tBLACKLIST       :\n"

for vcf in "${BLACKLIST[@]}";
do
    printf "\t\t$vcf\n"
done

printf "\tMINIMUM_QUALITY : $MINIMUM_QUALITY\n"
printf "\tMINIMUM_COVERAGE: $MINIMUM_COVERAGE\n"
printf "\tMINIMUM_VAF     : $MINIMUM_VAF\n"

if [ $USE_SGE == "YES" ]; then
    printf "\tMAIL            : $MAIL\n"
fi;

printf "\tCLEANUP         : $CLEANUP\n"


# Create job script
JOB_ID=SNVFI_Filtering_`date | md5sum | cut -d' ' -f1`
JOB_LOG=$OUT_DIR/$JOB_ID.log
JOB_ERR=$OUT_DIR/$JOB_ID.err
JOB_SCRIPT=$OUT_DIR/$JOB_ID.sh

echo "$SNVFI_ROOT/SNVFI_filtering.sh $runtime_config $runtime_settings" >> $JOB_SCRIPT

if [ "$USE_SGE" == "YES" ]; then
    qsub -q all.q -P cog_bioinf -pe threaded $MAXIMUM_THREADS -l h_rt=2:0:0 -l h_vmem=10G -N $JOB_ID -e $JOB_ERR -o $JOB_LOG -m a -M $MAIL $JOB_SCRIPT
else
    sh $JOB_SCRIPT 1>> $JOB_LOG 2>> $JOB_ERR
fi



