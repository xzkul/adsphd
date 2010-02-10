# Makefile for phd. Created Thu Feb 04 11:21:04 2010,

# Define default target before importing other Makefile settings
all: default

# Include general settings
include Makefile.settings

# Other tex files that might be included in $(MAINTEX)
CHAPTERS = $(wildcard $(CHAPTERSDIR)/*/*.tex)
CHAPTERNAMES = $(subst ./,,$(shell (cd $(CHAPTERSDIR); find -mindepth 1 -maxdepth 1 -type d)))
CHAPTERDEFS = $(wildcard $(CHAPTERSDIR)/*/$(DEFS))
CHAPTERMAKEFILES = $(addsuffix /Makefile,$(shell find $(CHAPTERSDIR) -mindepth 1 -maxdepth 1 -type d))
CHAPTERAUX = $(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername).aux)

DVIFILE = $(MAINTEX:.tex=.dvi)
PSFILE = $(MAINTEX:.tex=.ps)
PDFFILE = $(MAINTEX:.tex=.pdf)
BBLFILE = $(MAINTEX:.tex=.bbl)
NOMENCLFILE = $(MAINTEX:.tex=.nls)

TOREMOVE = $(wildcard *.toc) \
		   $(wildcard *.aux) \
		   $(wildcard *.log) \
		   $(wildcard *.dvi) \
		   $(wildcard *.bbl) \
		   $(wildcard *.blg) \
		   $(wildcard *.log) \
		   $(wildcard *.lof) \
		   $(wildcard *.lot) \
		   $(wildcard *.ilg) \
		   $(wildcard *.out)

TOREMOVE_RC = $(wildcard *.pdf) \
		      $(wildcard *.ps) \
			  $(wildcard *.glo) \
			  $(wildcard *.gls) \
			  $(wildcard *.nlo) \
			  $(wildcard *.nls)

IGNOREINCHAPTERMODE = \(makefrontcover\|makebackcover\|maketitle\|includepreface\|includeabstract\|listoffigures\|listoftables\|printnomenclature\|includecv\|includepublications\|includeonly\|instructionschapters\)

PDFNUP = $(shell which pdfnup)

test:
	@echo $(PDFNUP)
	#@echo $(CHAPTERAUX)
	#echo 'lkasdjf'
	#echo $(CHAPTERNAMES)
	#echo $(wildcard $(CHAPTERSDIR)/*)/Makefile
	#echo $(wildcard $(CHAPTERSDIR)/*/$(DEFS))
	#echo $(CHAPTERDEFS)

# Default build target
default: $(PSFILE) $(PDFFILE)

##############################################################################
### BUILD PDF/PS (with relaxed dependencies on bibtex and nomenclature)  #####

$(DVIFILE): $(MAINTEX) $(DEFS) $(EXTRADEP) $(CHAPTERMAKEFILES) $(BBLFILE) $(NOMENCLFILE)

# Other standard rules are included in Makefile.settings:
#
#   $(DVIFILE): %.dvi : $(FORCE_REBUILD)
#   %.ps: %.dvi
#   %.pdf: %.ps

##############################################################################
### PUT 2 LOGICAL PAGES ON SINGLE PHYSICAL PAGE  #############################

.PHONY: psnup
psnup: $(PDFFILE)
	if [ "$(PDFNUP)" != "" ]; then \
		pdfnup --frame true $<;\
	else \
		pdftops -q $< - | psnup -q -2 -d1 -b0 -m20 -s0.65 > $(PDFFILE:.pdf=-2x1.ps);\
		echo "Finished: output is $$PWD/$(PDFFILE:.pdf=-2x1.ps)";\
	fi;

##############################################################################
### BUILD THESIS AND CHAPTERS ################################################
.PHONY: thesisfinal
thesisfinal: $(MAINTEX) $(DEFS) $(FORCE_REBUILD)
	@make nomenclature
	@echo "Running bibtex..."
	$(BIBTEX) $(basename $<)
	@echo "Running latex a second time..."
	$(TEX) $<
	@echo "Running latex a third time..."
	$(TEX) $<
	@echo "Converting dvi -> ps -> pdf..."
	make $(PDFFILE)
	@echo "Done."

$(DEFS): $(DEFS_THESIS) $(CHAPTERDEFS)
	cat $^ > $@

%: $(CHAPTERAUX) $(CHAPTERSDIR)/%  
	@echo "Creating chapter 'my$@'..."
	grep -v '$(IGNOREINCHAPTERMODE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERSDIR)/$@/$@}\\begin{document}|' > my$@.tex
	make my$@.bbl 
	$(TEX) my$@.tex
	$(TEX) my$@.tex
	make my$@.ps my$@.pdf
	make cleanpar TARGET=my$@
	$(RM) my$@.tex

$(CHAPTERAUX): $(DEFS) $(CHAPTERS)
	@echo "Creating $@ ..."
	$(TEX) $(MAINTEX)

.PHONY: chaptermakefiles
chaptermakefiles: $(CHAPTERMAKEFILES)

$(CHAPTERSDIR)/%/Makefile: $(CHAPTERSDIR)/Makefile.chapters
	@echo "Generating chapter makefile..."
	@echo "# Autogenerated Makefile, $(shell date)." > $@
	@echo "MAINDIR=$(PWD)" >> $@
	@echo "include ../Makefile.chapters" >> $@

##############################################################################
### BIBTEX/REFERENCES ########################################################

.PHONY: ref
ref: 
	@make $(BBLFILE)

%.bbl: %.tex $(MAINBIBTEXFILE)
	@echo "Running latex..."
	$(TEX) $<
	@echo "Running bibtex..."
	$(BIBTEX) $(<:.tex=)
	$(RM) $(<:.tex=.dvi)

reflist:
	fgrep "\cite" $(MAINTEX) | grep -v "^%.*" | \
		sed -n -e 's/^.*cite{\([^}]*\)}.*/\1/p' | sed -e 's/,/\n/g' | uniq $(PIPE)

reflist.bib: PIPE := | python extract_from_bibtex.py --bibfile=$(MAINBIBTEXFILE)--stdin > reflist.bib
reflist.bib: reflist

##############################################################################
### NOMENCLATURE  ############################################################

.PHONY: nomenclature
nomenclature: 
	@make $(NOMENCLFILE)
	
%.nls: %.tex
	@echo "Running latex..."
	$(TEX) $<
	@echo "Creating nomenclature..."
	$(MAKEINDEX) $(<:.tex=.nlo) -s nomencl.ist -o $(<:.tex=.nls)
	$(RM) $(DVIFILE)

##############################################################################
### FORCE REBUILD ############################################################

#force: touch all
force_rebuild: force_rebuild_ all
force_rebuild_:
	touch $(FORCE_REBUILD)

$(FORCE_REBUILD):
	[ -e $(FORCE_REBUILD) ] || touch $(FORCE_REBUILD)

##############################################################################
### FIGURES ##################################################################

image: figures

figures:
	cd image && make

figurelist:
	@fgrep includegraphic $(MAINTEX) | sed 's/^[ \t]*//' | grep -v "^%" | \
		sed -n -e 's/.*includegraphics[^{]*{\([^}]*\)}.*/\1/p' $(FIGPIPE)

figurelist.txt: FIGPIPE := > figurelist.txt
figurelist.txt: figurelist

##############################################################################
### CLEAN etc ################################################################

.PHONY: clean
clean:
	$(RM) $(TOREMOVE)

.PHONY: realclean
realclean: clean
	make realcleanpar TARGET=$(basename $(MAINTEX))
	# Remove autogenerated $(DEFS)
	$(RM) $(DEFS)
	# Remove all compiled chapters
	@echo "Removing temporary files for all chapters..."
	for i in $(CHAPTERSDIR)/*;\
	do \
		i=$(basename "$$i");\
		if [ -f my"$$i".pdf ]; then $(RM) my"$$i".pdf; fi;\
		if [ -f my"$$i".dvi ]; then $(RM) my"$$i".dvi; fi;\
		if [ -f my"$$i".ps ]; then $(RM) my"$$i".ps; fi;\
	done
	# Remove .aux files in chapters
	$(RM) $(CHAPTERSDIR)/*/*.aux

##############################################################################

s:
	echo gvim $(MAINTEX) $(MAINBIBTEXFILE) > $@
	chmod +x $@

##############################################################################
# vim: tw=78