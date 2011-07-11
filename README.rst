#######################################
Load [parts of] a TRED DB into Postgres
#######################################

Two scripts to load parts of the raw TRED DB release files into a Posgres DB.

Tested and working on OSX 10.6.7 and using Postgres 9.0.4 (64bit build).

Current release version of these scripts: ``1.0``

Copyright and license
---------------------

License: MIT (see below)

Copyright (C) 2011 by Florian Leitner. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Components
----------

A bash script to extract the data (``extract.sh``) and a SQL script to load the data, creating the tables, and doing some interesting queries (``tred.sql``).

Limitations
-----------

The current extraction focuses on extracting only those TRED interactions from the raw DB files that have (a) a PMID referencing the interaction, (b) a known database identifier for the transcription factor TF, and (c) a known database identifier for the target gene TG. Any relations that do not meet this criteria (about 10% of all stored TRED TF-TG relations) are dropped by the extraction step.

Environment setup
-----------------

The idea is to have a directory with the scripts, that has a subdirectory with the raw DB files received from TRED. The only bad idea is to name the subdirectory ``tmp``, which will be created by the extraction script. Otherwise, any (meaningful...) subdirectory name is suitable; the date was chosen to keep track of multiple downloads of the TRED DB, because the raw data we received from TRED itself did not seem to be identified with a version number::

  mkdir tred
  cd tred
  mkdir <tred db release date, e.g. 14_03_2011>
  cp /path/to/tred/data/*.txt 14_03_2011/
  cp /path/to/tred.sql .
  cp /path/to/extract.sh .

Preparations
------------

In the SQL script (``tred.sql``), set the correct path to this main tred directory just created::

  vi tred.sql
  :4
  4w
  c:r ! pwd
  <ESC>
  J
  x
  x
  $
  a
  '
  <ESC>
  :wq

The result should be that line 4 in the file looks something like this::

  \set treddir '\'/home/username/work/data/tred'

Step-by0step instructions
-------------------------

**1. Create a DB in Postgres**


You can use any database name you desire; this is not of consequence in the further processing::

  psql -c 'CREATE DATABASE tred'

**2. Extract the data**

The next step will take a while, depending on the power of your machine. ``grep`` commands have been optimized, but it still takes a minute or two to run. The resulting raw file to dump into Postgres will be created in a directory 'tmp' relative to the CWD. The final line you should see is "DONE". You can re-run the script any time without having to create or clean the tmp directory extract.sh works with; it cleans the directory itself. The ouptut also shows you how many promoter entities and factor-to-promoter relations are being dropped due to the above mentioned limitations::

  . extract.sh <raw files directory, eg., 14_03_2011 as described above>

**3. Dump the data, show statistics, write output file**

Run the SQL script::

  psql -f tred.sql tred

You will get some output about creating implicit indices, but otherwise the script should exit cleanly (status 0). The last argument ("tred") should be the DB you chose earlier. The last command of the script will copy a new table to your '/tmp' (notice: global /tmp, not the tmp dir described before!) directory, in a file 'FactorGeneEvidence.txt', that contains what I had "hoped" to have found in TRED initially: All unique TG-TF-PMID triples, with the following columns:

#. PMID
#. TF source DB
#. TF source DB accession
#. TG source DB
#. TG source DB accession

The last command also gives you some interesting statistics of the loaded data right away. For my run on the TRED data, the statistics were:

* Curated Factor-Gene-PubMed Triples: ``6765``
* Curated Publications: ``3494``

Note that the Factor-Gene-PubMed Triples are for **unique** factor-to-gene relations, while the file produced in /tmp holds far more than those, because for each such unique triplet multiple *accessions* might exist on each side (ie., for the TF and TG). Also note that both numbers and the extracted file are not over all triples/publications in the TRED DB, but only for those that meet certain selection criteria: the TF-promoter relation curation quality must be 'known' (``fp_quality = 1``) and the promoter quality itself must be 'known' or 'known, curated' (``p_quality < 3``).

That's it, folks - **good luck**!