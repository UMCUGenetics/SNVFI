# @Date: 02-02-2016
# @Author(s): Francis Blokzijl, Sander Boymans
# @Title: SNVFI 
# @Description: Pipeline for filtering somatic SNVs for clonal (organoid) cultures
# @Args: (1) Path to .cfg file containing paths to tools. (2) Path to .ini file containing
# job specific settings

# -----------------------------------------------------------------------------
# Define helper functions
# -----------------------------------------------------------------------------
function join { local IFS="$1"; shift; echo "$*"; }
function techo { echo `date +"%Y-%m-%d_%H:%M:%S"`": "$*; }

# Read default configuration file
config=$1
ini=$2

source $config
source $ini

# create tmp dir and log-files
TMP_DIR=$OUT_DIR/tmp

if [ ! -d $TMP_DIR ]; then
    mkdir $TMP_DIR
fi



# get sample names
SAMPLES=($(grep -P "^#CHROM" < $SNV))

REF_NAME=${SAMPLES[ $(( $REF+8 )) ]}
SUB_NAME=${SAMPLES[ $(( $SUB+8 )) ]}

LOG=$OUT_DIR/$SUB_NAME"_"$REF_NAME"_filter-log.txt"
ERR=$OUT_DIR/$SUB_NAME"_"$REF_NAME"_filter-err.txt"
COUNTS=$OUT_DIR/$SUB_NAME"_"$REF_NAME"_filter-count.txt"

#get version
INSTALL_DIR=$( cd $( dirname '${BASH_SOURCE[0]}' ) && pwd )
SCRIPT_NAME=`basename "$0"`
VERSION=$INSTALL_DIR/$SCRIPT_NAME

# -----------------------------------------------------------------------------
# Print reference and subject sample names, as feedback for user
# -----------------------------------------------------------------------------
techo $SUB_NAME" is used as the subject sample" >> $LOG
techo $REF_NAME" is used as the reference sample" >> $LOG

# make output file names
s="_Q"$QUAL"_PASS_"$COV"X_autosomal.vcf"
vcf_filtered="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

s="_Q"$QUAL"_PASS_"$COV"X_autosomal.vcf.gz"
vcf_filtered_zip="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

s="_Q"$QUAL"_PASS_"$COV"X_autosomal_nonBlacklist.vcf.gz"
vcf_no_blacklist="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

s="_Q"$QUAL"_PASS_"$COV"X_autosomal_nonBlacklist_noEvidenceRef.vcf"
vcf_no_evidence_and_called="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

s="_Q"$QUAL"_PASS_"$COV"X_PNR"$PNR"_autosomal_nonBlacklist_final.vcf"
vcf_final="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

s="_PNR.pdf"
pnr_plot_file="$OUT_DIR$SUB_NAME"_"$REF_NAME$s"

techo "(1) Filtering SNV file with bio_vcf STARTED" >> $LOG
# bio vcf is zero based: subtract one from ref and sub index
export TMPDIR=$TMP_DIR
cat $SNV | $BIOVCF -i --num-threads $MAX_THREADS --thread-lines 50_000 --filter "r.filter=='PASS' and r.qual>=$QUAL and r.chrom.to_i>0 and r.chrom.to_i<23" \
--sfilter-samples $(($REF-1)),$(($SUB-1)) --sfilter "!s.empty? and s.dp>=$COV" 1>$vcf_filtered 2>>$ERR
$TABIX/bgzip -c $vcf_filtered 1> $vcf_filtered_zip 2>> $ERR
$TABIX/tabix -p vcf $vcf_filtered_zip 2>> $ERR

techo "(1) Filtering SNV file with bio_vcf DONE" >> $LOG

echo "Input file:" > $COUNTS
grep -Pvc "^#" $SNV >> $COUNTS

echo "Q"$QUAL" PASS "$COV"X autosomal:" >> $COUNTS
grep -Pvc "^#" $vcf_filtered >> $COUNTS

techo "(2) Removing blacklisted SNPs from SNV file STARTED" >> $LOG
COUNT=1
vcf_tmp=$vcf_filtered_zip
for vcf in "${BLACKLIST[@]}";
do
    OUT=$TMP_DIR/$SUB_NAME"_"$REF_NAME"_Q"$QUAL"_PASS_"$COV"X_autosomal_nonBlacklist_"$COUNT
        
    $VCFTOOLS/vcftools --gzvcf $vcf_tmp --exclude-positions $vcf --recode --recode-INFO-all --out $OUT 2>>$ERR
    $TABIX/bgzip -c $OUT.recode.vcf > $OUT.recode.vcf.gz 2>>$ERR
    $TABIX/tabix $OUT.recode.vcf.gz 2>>$ERR

    echo "Not in blacklist $vcf: " >> $COUNTS
    zgrep -Pvc "^#" $OUT.recode.vcf.gz >> $COUNTS
    
    vcf_tmp=$OUT.recode.vcf.gz
    ((COUNT++))
done

mv $vcf_tmp $vcf_no_blacklist
mv $vcf_tmp.tbi $vcf_no_blacklist.tbi

techo "(2) Removing blacklisted SNPs from SNV file DONE" >> $LOG

#Load appropriate R version
module load R/3.2.2
techo "(3) Filtering SNV file with R STARTED" >> $LOG
Rscript $RSCRIPT $vcf_no_blacklist $REF $SUB $PNR $vcf_no_evidence_and_called $vcf_final $pnr_plot_file 2>>$ERR
techo "(3) Filtering SNV file with R DONE" >> $LOG




#add filter steps to header
vcf_final_tmp=$vcf_final"_tmp"

TIME=`date +"%Y-%m-%d_%H:%M:%S"`
#FINAL_HEADER=`grep -P "^#" $vcf_final`
HEADER_ADD="##SNVFI_filtering=<Version=$VERSION, Date=$TIME, Tools='bio-vcf=$BIOVCF tabix=$TABIX vcftools=$VCFTOOLS rscript=$RSCRIPT', SNV=$SNV, SUB=$SUB, REF=$REF, OUT_DIR=$OUT_DIR, QUAL=$QUAL, COV=$COV, PNR=$PNR, BLACKLIST=["
HEADER_ADD+=`join , ${BLACKLIST[@]}`
HEADER_ADD+="]>"

grep -P "^##" $vcf_final > $vcf_final_tmp
echo $HEADER_ADD >> $vcf_final_tmp
grep -P "^#CHROM" $vcf_final >> $vcf_final_tmp
grep -Pv "^#" $vcf_final >> $vcf_final_tmp
mv $vcf_final_tmp $vcf_final

techo "(4) Writing info on mutation numbers to log file STARTED" >> $LOG

# Write info on mutations numbers to log file
echo "No evidence reference and called:" >> $COUNTS
grep -Pvc "^#" $vcf_no_evidence_and_called >> $COUNTS

echo "Called and PNR > $PNR in subject:" >> $COUNTS
grep -Pvc "^#" $vcf_final >> $COUNTS

techo "(4) Writing info on mutation numbers to log file DONE" >> $LOG
techo "(5) Removing files that are not needed STARTED" >> $LOG

# remove files that are not needed
if [ $CLEANUP == "YES" ]; then
    rm -r $TMP_DIR
    rm $OUT_DIR/*autosomal.vcf
    rm $OUT_DIR/*autosomal.vcf.gz
    rm $OUT_DIR/*autosomal.vcf.gz.tbi
    rm $OUT_DIR/*nonBlacklist.vcf.gz
    rm $OUT_DIR/*nonBlacklist.vcf.gz.tbi
fi

techo "(5) Removing files that are not needed DONE" >> $LOG
