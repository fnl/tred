#!/usr/bin/env sh
# usage: call with name of directory where the raw TRED DB dump files are
mkdir tmp || rm tmp/*

# EASY STUFF...
cut -f1,2 $1/Source.txt | tail +2 > tmp/source

cut -f1,2 $1/FactorPromoterQuality.txt | tail +2 > tmp/fp_quality

tail +2 $1/PromoterQuality.txt | awk '{print $1 "	" $3}' > tmp/p_quality

cut -f1 $1/GeneAnnotation.txt | tail +2 | sort | uniq > tmp/gene

cut -f1 $1/FactorAnnotation.txt | tail +2 | sort | uniq > tmp/factor

cut -f1,2,3 $1/GeneAnnotation.txt | tail +2 | sort | uniq > tmp/gene_accession

cut -f1,2,3 $1/FactorAnnotation.txt | tail +2 | sort | uniq > tmp/factor_accession

cut -f1 $1/FactorPromoterEvidence.txt | tail +2 | sort | uniq > tmp/factor_promoter

cut -f1,3 $1/FactorPromoterEvidence.txt | tail +2 | sort | uniq > tmp/factor_promoter_pubmed

# CLEAN Promoter AND FactorPromoter FIRST...
cut -f1,3,13 $1/Promoter.txt | tail +2 | sort | uniq > tmp/promoter.tmp
wc -l tmp/promoter.tmp
# remove promoters that have not known gene
awk '{$0="	"$0"	"}1' tmp/gene > tmp/gene.pattern
split -l 100 tmp/gene.pattern tmp/gene.pattern.
for CHUNK in tmp/gene.pattern.* ; do
  grep -f "$CHUNK" tmp/promoter.tmp >> tmp/promoter
done
wc -l tmp/promoter

cut -f1,2,3,8 $1/FactorPromoter.txt | tail +2 | sort | uniq > tmp/factor_promoter_rel.tmp
wc -l tmp/factor_promoter_rel.tmp
# Note: the next three filtering steps remove about 10% "dead-end" relations
# remove factor_promoter relations that have no pubmed reference
awk '{$0="^"$0"	"}1' tmp/factor_promoter > tmp/factor_promoter.pattern
split -l 100 tmp/factor_promoter.pattern tmp/factor_promoter.pattern.
for CHUNK in tmp/factor_promoter.pattern.* ; do
  grep -f "$CHUNK" tmp/factor_promoter_rel.tmp >> tmp/factor_promoter_rel.tmp2
done
sort tmp/factor_promoter_rel.tmp2 | uniq > tmp/factor_promoter_rel.tmp
wc -l tmp/factor_promoter_rel.tmp
rm tmp/factor_promoter_rel.tmp2
# remove factor_promoter relations that have no known gene
cut -f1 tmp/promoter | awk '{$0="	"$0"	[1-4]$"}1' > tmp/promoter.pattern
split -l 200 tmp/promoter.pattern tmp/promoter.pattern.
for CHUNK in tmp/promoter.pattern.* ; do
  grep -f "$CHUNK" tmp/factor_promoter_rel.tmp >> tmp/factor_promoter_rel.tmp2
done
sort tmp/factor_promoter_rel.tmp2 | uniq > tmp/factor_promoter_rel.tmp
wc -l tmp/factor_promoter_rel.tmp
rm tmp/factor_promoter_rel.tmp2
# remove factor_promoter relations that have no known factor
awk '{$0="^[0-9]\\+	"$0"	"}1' tmp/factor > tmp/factor.pattern
split -l 50 tmp/factor.pattern tmp/factor.pattern.
for CHUNK in tmp/factor.pattern.* ; do
  grep -f "$CHUNK" tmp/factor_promoter_rel.tmp >> tmp/factor_promoter_rel.tmp2
done
sort tmp/factor_promoter_rel.tmp2 | uniq > tmp/factor_promoter_rel
wc -l tmp/factor_promoter_rel
rm tmp/factor_promoter_rel.tmp2

rm tmp/*.pattern*
rm tmp/*.tmp
echo DONE
