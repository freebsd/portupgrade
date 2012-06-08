# $Id: Makefile,v 1.2 2006/08/14 17:34:11 sem Exp $

BUILDDIR=	.build

PKGTOOLS_SRC=	pkg.rb \
		pkgdb.rb \
		pkgdbtools.rb \
		pkginfo.rb \
		pkgmisc.rb \
		pkgtools.rb \
		pkgtsort.rb \
		pkgversion.rb \
		portinfo.rb \
		ports.rb \
		portsdb.rb

FILESGROUPS=	FILES PKGTOOLSFILES
FILES=		pkgtools.rb
PKGTOOLSFILES=	${PKGTOOLS_SRC:S,^,${BUILDDIR}/,g} pkgtools/revision.rb

.include "${.CURDIR}/Makefile.inc"

FILESDIR?=	${RUBY_SITELIBDIR}
PKGTOOLSFILESDIR=	${FILESDIR}/pkgtools

CLEANDIRS=	${BUILDDIR}

.for file in ${PKGTOOLS_SRC}
${BUILDDIR}/${file}: pkgtools/${file}
	${RUBY} -wc ${.ALLSRC}
	@${MKDIR} ${BUILDDIR}/
	${RUBY} -p \
		-e '$$_.sub %r:/usr/local:, "${PREFIX}"' \
		${.ALLSRC} > ${.TARGET}
.endfor

pkgtools/revision.rb: pkgtools/revision.rb.in ${.CURDIR}/../scripts/buildrev.sh .PHONY
	${.CURDIR}/../scripts/buildrev.sh

beforeinstall: install-mkdir

install-mkdir: .PHONY
	${MKDIR} ${PKGTOOLSFILESDIR}

.include <bsd.prog.mk>

.include "${.CURDIR}/../Makefile.compat"
