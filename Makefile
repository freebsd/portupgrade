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

REL_VERSION!=	${RUBY} -Ilib -rpkgtools -e 'puts Version'

DISTNAME=	pkgtools-${REL_VERSION}
DISTFILES=	${DISTNAME}.tar.bz2
CHANGELOG=	NEWS.md
README=		README.md

DOCOWN?=	${BINOWN}
DOCGRP?=	${BINGRP}
DOCMODE?=	444

DOCFILES=	${CHANGELOG} ${README}

install-doc: ${CHANGELOG}
	${MKDIR} ${DESTDIR}${DOCSDIR}
	${INSTALL} -c -o ${DOCOWN} -g ${DOCGRP} -m ${DOCMODE} \
		${DOCFILES} ${DESTDIR}${DOCSDIR}

clean: distclean

distclean:
	rm -f ${DISTFILES}

${DISTFILES}: ${CHANGELOG}
	git archive --prefix=${DISTNAME}/ --format=tar ${REL_VERSION}|tar -xf -
	rm -f lib/pkgtools/revision.rb
	scripts/buildrev.sh
	mv lib/pkgtools/revision.rb ${DISTNAME}/lib/pkgtools/
	tar -cf ${DISTFILES} ${DISTNAME}/
	rm -rf ${DISTNAME}/

dist: ${DISTFILES}

test:
	@env PORTSDIR=/usr/ports ${RUBY} -Ilib -I. tests/test_all.rb
