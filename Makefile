# $Id: Makefile,v 1.1.1.1 2006/06/13 12:58:59 sem Exp $

SUBDIR=	bin \
	etc \
	lib \
	man \
	misc

.if defined(NEED_COMPAT_SCRIPT)
SUBDIR+= compat
.endif

.include <bsd.subdir.mk>

.include "${.CURDIR}/Makefile.inc"

HOME?=		/home/knu
TMPDIR?=	/tmp

REL_DIRS=	${HOME}/freefall/public_distfiles \
		${HOME}/www.idaemons.org/data/distfiles

REL_MINOR?=	# none
.if !defined(REL_DATE)
REL_DATE!=	date '+%Y%m%d'
.endif
.if empty(REL_MINOR)
REL_VERSION=	${REL_DATE}
.else
REL_VERSION=	${REL_DATE}.${REL_MINOR}
.endif

DISTNAME=	pkgtools-${REL_VERSION}
TARBALL=	${DISTNAME}.tar.bz2
CHANGELOG=	NEWS.md
README=		README.md

PORTDIR=	${HOME}/work/ports/sysutils/portupgrade

DOCOWN?=	${BINOWN}
DOCGRP?=	${BINGRP}
DOCMODE?=	444

DOCFILES=	${CHANGELOG} ${README}

CLEANFILES=	pkgtools-*.tar.bz2

.if 0
install: install-doc
.endif

install-doc: ${CHANGELOG}
	mkdir -p ${DOCSDIR}
	${INSTALL} -c -o ${DOCOWN} -g ${DOCGRP} -m ${DOCMODE} \
		${DOCFILES} ${DESTDIR}${DOCSDIR}

clean: clean-release

clean-release:
	rm -f ${CLEANFILES} 

${TARBALL}: ${CHANGELOG}
	svn up
	svn export svn+ssh://svn.idaemons.org/home/svn/repos/pkgtools/trunk ${TMPDIR}/${DISTNAME}
	cp ${CHANGELOG} ${TMPDIR}/${DISTNAME}/
	tar -cf - -C ${TMPDIR} ${DISTNAME} | bzip2 -9c > ${TARBALL}
	rm -r ${TMPDIR}/${DISTNAME}

tarball: ${TARBALL}

release: ${CHANGELOG} ${TARBALL}
.for d in ${REL_DIRS}
	cp -p ${TARBALL} ${d}
.endfor

upload:
	@syncfreefall -f

port:
	@${RUBY} -i -pe \
		"sub /^PORTVERSION=.*/, %{PORTVERSION=\t${REL_VERSION}}" \
		${PORTDIR}/Makefile
	@cd ${PORTDIR}; make MASTER_SORT_REGEX=idaemons distclean makesum
	@cd ${PORTDIR}; cvs -d freefall:/home/ncvs di | less

commit:
	@cd ${PORTDIR}; cvs -d freefall:/home/ncvs di | $${PAGER:-more}
	@echo -n 'OK? '; read ans; expr "$$ans" : '[Yy]' > /dev/null
	@cd ${PORTDIR}; echo cvs -d freefall:/home/ncvs ci

test:
	@env PORTSDIR=/usr/ports ${RUBY} -Ilib -I. tests/test_all.rb
