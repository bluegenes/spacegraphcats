all: test

flakes:
	pyflakes search/*.py

lint:
	mypy spacegraphcats/*.py search/*.py --ignore-missing-imports

test:
	py.test spacegraphcats search


## Targets:
##
##   acido-search: execute a small build-and-search on 'acido' data set.
##   15genome-search: execute a medium build-and-search on 15 genomes.
##   shew-search: execute a small build-and-search on a real read data set
##   dory-test: execute a small build, index, search, and extract on the
##       'dory' data set.
##
##   podar-search: execute a search on the full podar data set
##       (requires 8GB RAM)
##   podar-download: download and set up a prebuilt podar catlas.
##       (see https://osf.io/h79um/?show=revision)
##
##   twofoo-extract: make, index, and search a combination of akker-reads
##	      and shew-reads; contains lots of strain variation.

acido-clean:
	-rm -r acido

# build cDBG
acido/cdbg.gxt: data/acido.fa.gz
	python -m spacegraphcats.build_contracted_dbg -k 31 -M 2e9 data/acido.fa.gz

# build catlas
acido/catlas.csv: acido/cdbg.gxt
	python -m spacegraphcats.catlas acido 1

# build minhashes database
acido/minhashes_info.json: acido/catlas.csv
	python -m search.make_catlas_minhashes acido -k 31 --scaled=1000
	python -m search.make_catlas_minhashes acido -k 21 --scaled=1000

# build a search signature
acido/acido-chunk1.fa.gz.sig: data/acido-chunk1.fa.gz
	sourmash compute -k 31 data/acido-chunk1.fa.gz --scaled 500 -f -o acido/acido-chunk1.fa.gz.sig

acido-search: acido/minhashes_info.json acido/acido-chunk1.fa.gz.sig
	python -m search.frontier_search acido/acido-chunk1.fa.gz.sig acido 0.1 --fullstats

acido-frontier-search-optimized: acido/minhashes_info.json acido/acido-chunk1.fa.gz.sig
	python -m search.frontier_search acido/acido-chunk1.fa.gz.sig acido 0.1  --purgatory


### 

15genome-clean:
	-rm -r 15genome/

# build cDBG
15genome/cdbg.gxt:
	python -m spacegraphcats.build_contracted_dbg -k 31 -M 4e9 data/15genome.fa.gz -o 15genome

# build catlas
15genome/catlas.csv: 15genome/cdbg.gxt
	python -m spacegraphcats.catlas 15genome 3

# build minhashes
15genome/minhashes_info.json: 15genome/catlas.csv
	python -m search.make_catlas_minhashes -k 31 --scaled=5000 15genome

# run search!
15genome-frontier-search: 15genome/minhashes_info.json
	python -m search.frontier_search data/15genome.5.fa.sig 15genome 0.1

15genome-frontier-search-optimized: 15genome/minhashes_info.json
	python -m search.frontier_search data/15genome.5.fa.sig 15genome 0.1 --purgatory

####

#
# shew-reads.abundtrim.gz is a collection of reads from podar data
# that maps to the Shewanella OS223 genome via bwa aln.  "Real" data,
# with known answer.  Note that there is significant overlap with the
# Shewanella OS185 genome; this is a data set with significant strain
# variation.
#

# prepared reads -- this is here only for record keeping & never
# needs to be done again.
XXXshew-reads.abundtrim.gz:
	trim-low-abund.py --normalize 12 -V -Z 10 -M 2e9 -C 3 -k 21 shewanella.mappedreads.fa -o shew-reads.abundtrim.gz --gzip

# download the prepared reads (27 MB) from OSF
shew-reads.abundtrim.gz:
	curl -L 'https://osf.io/7az9p/?action=download' > shew-reads.abundtrim.gz

# build cDBG
shew-reads/cdbg.gxt: shew-reads.abundtrim.gz
	python -m spacegraphcats.build_contracted_dbg -k 31 -M 4e9 shew-reads.abundtrim.gz -o shew-reads

# build catlas
shew-reads/catlas.csv: shew-reads/cdbg.gxt
	python -m spacegraphcats.catlas shew-reads 1

# build minhashes
shew-reads/minhashes_info.json: shew-reads/catlas.csv shew-reads/contigs.fa.gz
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 shew-reads

# download the shewanella genome from OSF
shew-reads/shewanella-OS223.fa.gz:
	mkdir -p shew-reads
	curl -L 'https://osf.io/yr8q6/?action=download' -o shew-reads/shewanella-OS223.fa.gz

# compute shewanella genome signature
shew-reads/shewanella-OS223.fa.gz.sig: shew-reads/shewanella-OS223.fa.gz
	sourmash compute -k 31 --scaled=1000 shew-reads/shewanella-OS223.fa.gz -o shew-reads/shewanella-OS223.fa.gz.sig

# run frontier search
shew-search: shew-reads/shewanella-OS223.fa.gz.sig shew-reads/minhashes_info.json
	python -m search.frontier_search shew-reads/shewanella-OS223.fa.gz.sig shew-reads 0.1 --purgatory

#
# akker-reads.abundtrim.gz is a collection of reads from podar data
# that maps to the Akkermansia muciniphila ATCC BAA-835 genome via bwa aln.
# "Real" data, with known answer.  There does not appear to be significant
# overlap with other genomes in the Podar data set; so, no significant strain
# variation.
#

akker-reads.abundtrim.gz:
	curl -o akker-reads.abundtrim.gz -L https://osf.io/dk7nb/download

# build cDBG
akker-reads/cdbg.gxt: akker-reads.abundtrim.gz
	python -m spacegraphcats.build_contracted_dbg -k 31 -M 4e9 akker-reads.abundtrim.gz -o akker-reads

###

#
# SRR606249.keep.fq.gz is the 'podar' data set in reads - from Shakya et al.,
# 2013.  Here it has been prepared from reads that were first QCed as in
# Awad et al. (unpublished), and then normalized and trimmed like so:
#
#    trim-low-abund.py -k 21 -M 8e9 -C 10 -V --normalize 10
#			SRR606249.pe.qc.fq.gz --gzip -o SRR606249.keep.fq.gz
#

# download the prepared reads - 5.3GB in size.
SRR606249.keep.fq.gz:
	curl -L https://osf.io/45xay/?action=download > SRR606249.keep.fq.gz

# download the prepared catlas/minhashes: 250 MB.
podar-download:
	curl -L https://osf.io/g6n4k/?action=download > podar-2017.05.06b.tar.gz
	tar xzf podar-2017.05.06b.tar.gz
	touch podar.ng SRR606249.keep.fq.gz podar/*

# load reads into a nodegraph (8 GB in size)
podar.ng: SRR606249.keep.fq.gz
	load-graph.py -n -M 8e9 -k 31 podar.ng SRR606249.keep.fq.gz

podar/cdbg.gxt: podar.ng SRR606249.keep.fq.gz
	python -m spacegraphcats.build_contracted_dbg -l podar.ng \
		SRR606249.keep.fq.gz -o podar

podar/catlas.csv: podar/cdbg.gxt
	python -m spacegraphcats.catlas podar 3

####

#
# twofoo targets, below, use a synthetic mixture of reads from podar data -
# the shew-reads.abundtrim.gz (mapping to Shewanella baltica OS223) and
# akker-reads.abundtrim.gz (mapping to Akkermansia muciniphila ATCC BAA-835).
# Many of the shew-reads also map to S. baltica OS185, while the akker-reads
# do not; so this is a good mixture for testing the effects of strain variation
# on catlas foo.

# make synthetic mix data set 'twofoo'
twofoo.fq.gz: shew-reads.abundtrim.gz akker-reads.abundtrim.gz
	gunzip -c shew-reads.abundtrim.gz akker-reads.abundtrim.gz | gzip -9c > twofoo.fq.gz

twofoo.fq.gz.bgz: twofoo.fq.gz
	python -m search.make_bgzf twofoo.fq.gz

# build DBG
twofoo.ng: twofoo.fq.gz
	load-graph.py -n -M 2e9 -k 31 twofoo.ng twofoo.fq.gz

# build cDBG
twofoo/cdbg.gxt: twofoo.fq.gz twofoo.ng
	python -m spacegraphcats.build_contracted_dbg -l twofoo.ng twofoo.fq.gz -o twofoo

# build catlas
twofoo/catlas.csv: twofoo/cdbg.gxt
	rm -f twofoo/*.checkpoint twofoo/first_doms.txt twofoo/minhashes_info.json
	python -m spacegraphcats.catlas twofoo 1

# build minhashes
twofoo/minhashes_info.json: twofoo/catlas.csv twofoo/contigs.fa.gz
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=43
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=44
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=45
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=46
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=47
	python -m search.make_catlas_minhashes -k 31 --scaled=1000 twofoo --seed=48

twofoo.labels: twofoo/contigs.fa.gz twofoo.fq.gz.bgz
	python -m search.label_cdbg twofoo twofoo.fq.gz.bgz twofoo.labels -k 31 -M 1e9

twofoo-extract-1: twofoo/minhashes_info.json twofoo.labels
	python -m search.extract_reads data/63.fa.gz twofoo 0.2 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.63.31.fq --scaled=1000 --seed 43

twofoo-extract-1b: twofoo/minhashes_info.json 
	python -m search.extract_contigs data/63.fa.gz twofoo 0.2 --scaled=1000 --seed 43-48

twofoo-extract-conn: twofoo/minhashes_info.json twofoo/contigs.fa.gz_screed
	python -m search.extract_contigs_conn data/63.fa.gz twofoo 0.2 --scaled=1000 --seed 43,44 --diffuse-radius=5

twofoo-extract-bulk:
	python -m search.extract_reads_batch twofoo twofoo.fq.gz.bgz twofoo.labels foo --query data/{2,47,63}.fa.gz --seed 43-48

twofoo-extract-bulk-2:
	python -m search.extract_contigs_batch twofoo foo2 --query data/{2,47,63}.fa.gz --seed 43-48

twofoo-extract-bulk-3:
	python -m search.extract_contigs_batch twofoo foo2 --query data/2.fa.gz --seed 43-48

twofoo-extract: twofoo/minhashes_info.json twofoo.labels
	python -m search.extract_reads data/63.fa.gz twofoo 0.2 -k 31 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.63.fq
	python -m search.extract_reads data/47.fa.gz twofoo 0.2 -k 31 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.47.fq
	python -m search.extract_reads data/2.fa.gz twofoo 0.2 -k 31 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.2.fq

twofoo-extract-200k: twofoo/minhashes_info.json twofoo.labels
	python -m search.extract_reads_by_frontier data/shew-os223-200k.fa.sig twofoo 0.2 -k 21 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.63.200k.fq
	python -m search.extract_reads_by_frontier data/shew-os223-200k.fa.sig twofoo 0.2 -k 21 twofoo.fq.gz.bgz twofoo.labels twofoo.frontier.63.200k.empty.fq --no-remove-empty

make-long-contigs:
	extract-long-sequences.py -l 2000 akker-reads/contigs.fa.gz | gzip -9c > akker-contigs-2k.fa.gz
	#extract-long-sequences.py -l 1000 shew-reads/contigs.fa.gz | gzip -9c > shew-contigs-2k.fa.gz

extract-from-long-contigs:
	python -m search.extract_contigs --diffuse-radius=3 akker-contigs-2k.fa.gz twofoo 0.0 -o akker-long-oh00.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 akker-contigs-2k.fa.gz twofoo 0.2 -o akker-long-oh02.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 akker-contigs-2k.fa.gz twofoo 0.4 -o akker-long-oh04.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 akker-contigs-2k.fa.gz twofoo 0.6 -o akker-long-oh06.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 akker-contigs-2k.fa.gz twofoo 0.8 -o akker-long-oh08.fa --seed 43-47

foo:
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 0.0 -o shew-long-oh00.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 0.2 -o shew-long-oh02.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 0.4 -o shew-long-oh04.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 0.6 -o shew-long-oh06.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 0.8 -o shew-long-oh08.fa --seed 43-47
	python -m search.extract_contigs --diffuse-radius=3 shew-reads.megahit.2k.fa.gz twofoo 1.0 -o shew-long-oh10.fa --seed 43-47
	sourmash compute -k 31 --scaled=1000 shew-long-oh??.fa akker-long-oh??.fa -f

extract-from-long-contigs-search:
	sourmash search --containment data/63-os223.sig shew-long-oh02.fa.sig
	sourmash search --containment data/63-os223.sig shew-long-oh04.fa.sig
	sourmash search --containment data/63-os223.sig shew-long-oh06.fa.sig
	sourmash search --containment data/63-os223.sig shew-long-oh08.fa.sig
	sourmash search --containment data/63-os223.sig shew-long-oh10.fa.sig
	sourmash search --containment data/2-akker.sig akker-long-oh02.fa.sig

extract-from-long-contigs-search-2:
	sourmash search --containment data/47-os185.sig shew-long-oh02.fa.sig
	sourmash search --containment data/47-os185.sig shew-long-oh04.fa.sig
	sourmash search --containment data/47-os185.sig shew-long-oh06.fa.sig
	sourmash search --containment data/47-os185.sig shew-long-oh08.fa.sig
	sourmash search --containment data/47-os185.sig shew-long-oh10.fa.sig

extract-from-long-contigs-search-3:
	sourmash search --containment data/63-os223.sig akker-long-oh02.fa.sig --threshold=0.0
	sourmash search --containment data/47-os185.sig akker-long-oh02.fa.sig --threshold=0.0

extract-from-long-contigs-search-4:
	sourmash search --containment data/2-akker.sig shew-long-oh02.fa.sig
	sourmash search --containment data/2-akker.sig shew-long-oh04.fa.sig
	sourmash search --containment data/2-akker.sig shew-long-oh06.fa.sig
	sourmash search --containment data/2-akker.sig shew-long-oh08.fa.sig
	sourmash search --containment data/2-akker.sig shew-long-oh10.fa.sig
###

#
# these are targets for quick testing and/or obscure script testing.
#
# dory-test runs through the entire pipeline on a Doryteuthis transcriptome
# subset.
#

dory-test: data/dory-subset.fa data/dory-head.fa
	rm -fr dory
	load-graph.py -k 21 -M 1e8 dory-subset.ng data/dory-subset.fa
	python -m spacegraphcats.build_contracted_dbg -l dory-subset.ng data/dory-subset.fa -o dory
	python -m spacegraphcats.catlas dory 1
	python -m search.make_catlas_minhashes -k 21 --seed=43 --scaled=1000 dory
	python -m search.make_bgzf data/dory-subset.fa
	python -m search.label_cdbg dory dory-subset.fa.bgz dory.labels -k 21
	python -m search.extract_reads data/dory-head.fa dory 0.2 -k 21 dory-subset.fa.bgz dory.labels dory-head.matches.fa
	sourmash compute -k 21 -f dory-head.matches.fa --scaled=1000
	sourmash compute -k 21 -f data/dory-head.fa --scaled=1000
	sourmash compare dory-head.matches.fa.sig dory-head.fa.sig

twofoo-test:
	python -m search.extract_reads_by_shadow_ratio twofoo twofoo.fq.gz.bgz twofoo.labels twofoo.shadow.out.fa -k 31
	python -m search.extract_reads_batch twofoo twofoo.fq.gz.bgz twofoo.labels foo --query data/2.fa.gz -k 31
	python -m search.extract_contigs_batch twofoo foo --query data/2.fa.gz -k 31
