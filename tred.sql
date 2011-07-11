-- Configuration
----------------

\set treddir '\'/home/username/work/data/tred'

\set basedir :treddir '/tmp'

-- Path setup
-------------

\set source :basedir '/source\''
\set p_quality :basedir '/p_quality\''
\set fp_quality :basedir '/fp_quality\''
\set gene :basedir '/gene\''
\set factor :basedir '/factor\''
\set factor_promoter :basedir '/factor_promoter\''
\set gene_accession :basedir '/gene_accession\''
\set factor_accession :basedir '/factor_accession\''
\set promoter :basedir '/promoter\''
\set factor_promoter_pubmed :basedir '/factor_promoter_pubmed\''
\set factor_promoter_rel :basedir '/factor_promoter_rel\''

-- Create the tables and load them
----------------------------------

-- PRIMARY ENTITIES
-- Source
CREATE TABLE source (src_id smallint PRIMARY KEY, name varchar(32));
COPY source FROM :source WITH DELIMITER E'\t' CSV;

-- PromoterQuality
CREATE TABLE p_quality (quality smallint PRIMARY KEY, name varchar(32));
COPY p_quality FROM :p_quality WITH DELIMITER E'\t' CSV;

-- FactorPromoterQuality
CREATE TABLE fp_quality (quality smallint PRIMARY KEY, name varchar(32));
COPY fp_quality FROM :fp_quality WITH DELIMITER E'\t' CSV;

-- unique gene_ids in GeneAnnotation (we only need DB-referenced genes)
CREATE TABLE gene (gene_id bigint PRIMARY KEY);
COPY gene FROM :gene WITH DELIMITER E'\t' CSV;

-- unique f_ids in FactorAnnotation (we only need DB-referenced factors)
CREATE TABLE factor (f_id bigint PRIMARY KEY);
COPY factor FROM :factor WITH DELIMITER E'\t' CSV;

-- unique fp_ids in FactorPromoterEvidence (we only need "published" relations)
CREATE TABLE factor_promoter (fp_id bigint PRIMARY KEY);
COPY factor_promoter FROM :factor_promoter WITH DELIMITER E'\t' CSV;

-- WEAK ENTITIES
-- GeneAnnotation
CREATE TABLE gene_accession (
  gene_id bigint REFERENCES gene ON DELETE cascade ON UPDATE cascade,
  src_id smallint REFERENCES source ON DELETE cascade ON UPDATE cascade,
  accession varchar(32),
  PRIMARY KEY (gene_id, src_id, accession));
COPY gene_accession FROM :gene_accession WITH DELIMITER E'\t' CSV;

-- FactorAnnotation
CREATE TABLE factor_accession (
  f_id bigint REFERENCES factor ON DELETE cascade ON UPDATE cascade,
  src_id smallint REFERENCES source ON DELETE cascade ON UPDATE cascade,
  accession varchar(32),
  PRIMARY KEY (f_id, src_id, accession));
COPY factor_accession FROM :factor_accession WITH DELIMITER E'\t' CSV;

-- Promoter
CREATE TABLE promoter (
  p_id bigint PRIMARY KEY,
  gene_id bigint NOT NULL REFERENCES gene ON DELETE cascade ON UPDATE cascade,
  quality smallint NOT NULL
    REFERENCES p_quality ON DELETE cascade ON UPDATE cascade);
CREATE INDEX ON promoter (quality);
COPY promoter FROM :promoter WITH DELIMITER E'\t' CSV;

-- FactorPromoterEvidence
CREATE TABLE factor_promoter_pubmed (
  fp_id bigint REFERENCES factor_promoter ON DELETE cascade ON UPDATE cascade,
  pmid bigint,
  PRIMARY KEY(fp_id, pmid));
COPY factor_promoter_pubmed FROM :factor_promoter_pubmed
  WITH DELIMITER E'\t' CSV;

-- RELATIONSHIPS
-- FactorPromoter
CREATE TABLE factor_promoter_rel (
  fp_id bigint NOT NULL
    REFERENCES factor_promoter ON DELETE cascade ON UPDATE cascade,
  f_id bigint NOT NULL
    REFERENCES factor ON DELETE cascade ON UPDATE cascade,
  p_id bigint NOT NULL
    REFERENCES promoter ON DELETE cascade ON UPDATE cascade,
  quality smallint NOT NULL
    REFERENCES fp_quality ON DELETE cascade ON UPDATE cascade,
  PRIMARY KEY (p_id, f_id, fp_id)); -- promoter is much larger than the others
CREATE INDEX ON factor_promoter_rel (quality);
COPY factor_promoter_rel FROM :factor_promoter_rel WITH DELIMITER E'\t' CSV;

-- Run some queries and export relationships
--------------------------------------------

-- SELECT all unique triplets of well-curated TF-TG ralations and their PMIDs
SELECT count(*) AS "Curated Factor-Gene-PubMed Triples" FROM (
SELECT DISTINCT fpr.f_id, p.gene_id, fpp.pmid
  FROM factor_promoter_rel AS fpr
  NATURAL JOIN factor_promoter_pubmed AS fpp
  JOIN promoter AS p
    ON p.p_id = fpr.p_id
    AND p.quality < 3
  WHERE fpr.quality = 1
) AS x;

-- SELECT only the PMIDs
SELECT count(*) AS "Curated Publications" FROM (
SELECT DISTINCT fpp.pmid
  FROM factor_promoter_rel AS fpr
  NATURAL JOIN factor_promoter_pubmed AS fpp
  JOIN promoter AS p
    ON p.p_id = fpr.p_id
    AND p.quality < 3
  WHERE fpr.quality = 1
) AS x;

-- COPY the accessions of the TFs and TGs to file
COPY (
SELECT DISTINCT
  fpp.pmid,
  fs.name AS f_src, fa.accession AS factor,
  gs.name AS g_src, ga.accession AS gene
  FROM factor_accession AS fa
  JOIN source AS fs
    ON fa.src_id = fs.src_id
  JOIN factor_promoter_rel AS fpr
    ON fa.f_id = fpr.f_id
    AND fpr.quality = 1
  JOIN factor_promoter_pubmed AS fpp
    ON fpr.fp_id = fpp.fp_id
  JOIN promoter AS p
    ON fpr.p_id = p.p_id
    AND p.quality < 3
  JOIN gene_accession AS ga
    ON p.gene_id = ga.gene_id
  JOIN source AS gs
    ON ga.src_id = gs.src_id
) TO '/tmp/FactorGeneEvidence.txt';
