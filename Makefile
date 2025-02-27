include Makefile.defs

PACKAGE = confMeta
VERSION = 0.4.2
TAR = $(PACKAGE)_$(VERSION).tar.gz



.PHONY: test-package update-src lib check-cran check covr manual \
	winbuild winbuild-devel webpage clean


update-src:
	sed -i -r -- 's/^Version:.*/Version: '$(VERSION)'/g' DESCRIPTION ;      
	sed -i -r -- 's/^Date:.*/Date: '`date +'%F'`'/g' DESCRIPTION ;
	$(RSCRIPT) -e "roxygen2::roxygenize('.')"

test-package:
	$(RSCRIPT) -e "devtools::test('.')"

tar: update-src
	mkdir -p lib
	$(RSCRIPT) -e "devtools::build(path = 'lib', args = '--compact-vignettes=both')"

bin: update-src
	mkdir -p lib
	$(RSCRIPT) -e "devtools::build(path = 'lib', binary = TRUE, args = '--compact-vignettes=both')"

submission: update-src
	mkdir -p lib
	$(RSCRIPT) -e "devtools::build(path = 'lib', manual = TRUE, args = '--compact-vignettes=both')"

check-cran: tar
	$(RSCRIPT) -e "devtools::check_built(path = './lib/$(TAR)', cran = TRUE)"

check-all: tar
	$(RSCRIPT) -e "devtools::check_built(path = './lib/$(TAR)', cran = TRUE, manual = TRUE, remote = TRUE)"

check: tar
	$(RSCRIPT) -e "devtools::check_built(path = './lib/$(TAR)', cran = FALSE)"

install: tar
	$(RSCRIPT) -e "install.packages('./lib/$(TAR)', repos = NULL, type = 'source')"

covr: 
	$(RSCRIPT) -e "covr::package_coverage()"

manual: update-src
	mkdir -p manual
	$(RSCRIPT) -e "devtools::build_manual(pkg = '.', path = 'manual')"

winbuild: update-src
	$(RSCRIPT) -e "devtools::check_win_release(args = '--compact-vignettes=both')"

winbuild-devel: update-src
	$(RSCRIPT) -e "devtools::check_win_devel(args = '--compact-vignettes=both')"

rhub: tar
	$(RSCRIPT) -e "rhub::check_for_cran(path = 'lib/$(TAR)')"

webpage: update-src
	$(RSCRIPT) -e "pkgdown::build_site()"

vignette: update-src
	$(RSCRIPT) -e "devtools::build_vignettes(pkg = '.')"

clean:
	rm -rf lib $(PACKAGE).Rcheck vignettes/cache/ vignettes/figure/ \
		vignettes/*.log vignettes/*.tex vignettes/*.aux \
		vignettes/*.synctex.gz vignettes/*.bbl vignettes/*.blg \
		vignettes/*.dvi vignettes/*.fdb_latexmk vignettes/*.fls \
		vignettes/*.out \
		manual \
		doc
