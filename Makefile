PREFIX=/usr
BINDIR=$(DESTDIR)$(PREFIX)/bin
MANS=sbank sbank-deposit sbank-balance sbank-project sbank-user sbank-time sbank-cluster sbank-submit
BINS=${MANS} sbank-balance.pl sbank-common-cpu_hrs.pl

# If ikiwiki is available, build static html docs suitable for being
# shipped in the software package.
ifeq ($(shell which ikiwiki),)
IKIWIKI=@echo "** ikiwiki not found, skipping building docs" >&2; true
## NO_IKIWIKI=1
else
IKIWIKI=ikiwiki
endif

all: build

build: docs
	for man in $(MANS); do \
		./mdwn2man $$man 1 doc/$$man.mdwn > $$man.1; \
	done

docs:
	$(IKIWIKI) doc html -v --wikiname slurm-bank --plugin=goodstuff \
		--no-usedirs --disable-plugin=openid --plugin=sidebar \
		--disable-plugin=shortcut \
		--disable-plugin=smiley \
		--plugin=comments --set comments_pagespec="*" \
		--exclude='news/.*'
ifdef NO_IKIWIKI
	$(MAKE) import-docs
endif

install: build
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m644 src/shflags $(DESTDIR)$(PREFIX)/bin
	for bin in $(BINS); do \
		install -m 644 src/$$bin $(DESTDIR)$(PREFIX)/bin; \
	done
	install -m 644 src/sbank-common $(DESTDIR)$(PREFIX)/bin;
	chmod +x $(DESTDIR)$(PREFIX)/bin/sbank
	chmod +x $(DESTDIR)$(PREFIX)/bin/sbank-balance.pl
	chmod +x $(DESTDIR)$(PREFIX)/bin/sbank-common-cpu_hrs.pl

	install -d $(DESTDIR)$(PREFIX)/share/man/man1
	for man in $(MANS); do \
		install -m 0644 $$man.1 $(DESTDIR)$(PREFIX)/share/man/man1; \
	done

	install -d $(DESTDIR)$(PREFIX)/share/doc/slurm-bank
	if [ -d html ]; then \
                rsync -a --delete html/ $(DESTDIR)$(PREFIX)/share/doc/slurm-bank/html/; \
        fi

runtests:
	$(MAKE) -C t runtests

test: build
	./wvtestrun $(MAKE) runtests	

clean:
	for man in $(MANS); do \
                rm -f $$man.1; \
        done
	rm -rf html doc/.ikiwiki

dist:
	git archive --format tar --prefix=$$(cat VERSION)/ HEAD | gzip > $$(cat VERSION).tar.gz
	git archive --format tar --prefix=$$(cat VERSION)-html/ html | gzip > $$(cat VERSION)-html.tar.gz

dist-withdocs: docs
	git archive --format tar --prefix=$$(cat VERSION)/ HEAD | tar xv -
	if [ -d html ]; then \
		rsync -a --delete html/ $$(cat VERSION)/html/; \
	fi
	tar czvf $$(cat VERSION).tar.gz $$(cat VERSION)/
	echo rm -rf $$(cat VERSION)


# update the local 'man' and 'html' branches with pregenerated output files, for
# people who don't have ikiwiki (and maybe to aid in google searches or something)
export-docs: docs
#	git update-ref refs/heads/man origin/man '' 2>/dev/null || true
#	GIT_INDEX_FILE=gitindex.tmp; export GIT_INDEX_FILE; \
#	rm -f $${GIT_INDEX_FILE} && \
#	git add -f Documentation/*.1 && \
#	git update-ref refs/heads/man \
#		$$(echo "Autogenerated man pages for $$(git describe)" \
#			| git commit-tree $$(git write-tree --prefix=Documentation) \
#				-p refs/heads/man) && \
	git update-ref refs/heads/html origin/html '' 2>/dev/null || true
	GIT_INDEX_FILE=gitindex.tmp; export GIT_INDEX_FILE; \
	rm -f $${GIT_INDEX_FILE} && \
	git add -f html/* && \
	git update-ref refs/heads/html \
		$$(echo "Autogenerated html pages for $$(git describe)" \
			| git commit-tree $$(git write-tree --prefix=html) \
				-p refs/heads/html)

# don't have ikiwiki but still want to be able to install the docs.
import-docs: clean
	mkdir -p html
	git archive origin/html | (cd html; tar -xvf -)

push-docs: export-docs
	git push origin html

.PHONY: docs
