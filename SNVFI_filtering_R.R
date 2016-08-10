# @Author: Francis Blokzijl   
# @Date: 8 September 2015
library(VariantAnnotation)
library(ggplot2)
library(reshape2)


# Input from command line
args = commandArgs(trailingOnly = TRUE)
vcf_file = args[1]
REF = as.integer(args[2])
SUB = as.integer(args[3])
#ADDED PNR ARGUMENT
PNR = as.numeric(args[4])
vcf_no_evidence_and_called = args[5]
vcf_final = args[6]
pnr_plot_file = args[7]

# Read vcf file
vcf = readVcf(vcf_file, "hg19")
n = dim(vcf)[1]
s = dim(vcf)[2]
vr = as(vcf, "VRanges")

sample_names = samples(header(vcf))

# Calculate Variant Allele Frequency
# This is the only way it works with VariantAnnotation vcf parsing AND multiple alternative alleles
# Get AD values
ad = CharacterList(geno(vcf)$AD)
# Coerce from character to integer
ad = lapply(ad, function(x) as.integer(x))
# Calculate alternative allele frequency as total altdepth / totaldepth
vaf = lapply(ad, function(x) (sum(x) - x[1]) / sum(x))
VAF_matrix = matrix(data = vaf, nrow = n, ncol = s)
altdepth = lapply(ad, function(x) sum(x) - x[1])
alt_matrix = matrix(data = altdepth, nrow = n, ncol = s)

# Called in subject sample
genotype = geno(vcf)$GT
called_in_subject = which(!(genotype[,SUB] == "0/0"))

VAF_in_subject = which(VAF_matrix[,SUB] >= PNR)

# No evidence in reference sample
no_evidence_reference = which(alt_matrix[,REF] < 1)

# Function to intersect multiple lists
overlap = function(x)
{
  A = Reduce('intersect', x)
  return(A)
}

# Find final set of SNVs that meet al criteria
final = overlap(list(called_in_subject, VAF_in_subject, no_evidence_reference))

# Called SNVS with no evidence in the reference
no_evidence_and_called = overlap(list(called_in_subject, no_evidence_reference))

# --------------------- OUTPUT VCFs ---------------------------

writeVcf(vcf[no_evidence_and_called,], vcf_no_evidence_and_called)
writeVcf(vcf[final,], vcf_final)

# --------------------- VAF/PNR plot ------------------------------
selection = overlap(list(called_in_subject, no_evidence_reference))
dat = as.data.frame(VAF_matrix[selection, SUB])
dat = melt(dat)

pdf(pnr_plot_file)
ggplot(dat, aes(x=value)) + 
  geom_histogram(aes(y=..density..), binwidth=0.01) +
  geom_density(alpha=.2, fill="#FF6666") + 
  scale_x_continuous(limits=c(0,1)) +
  labs(x = "Fraction non-reference (PNR)") +
  ggtitle(sample_names[SUB])
dev.off()

