# $Id: Makefile,v 1.1.1.1 2006/06/13 12:59:00 sem Exp $

BUILDDIR=	.build

FILES=	${BUILDDIR}/pkg.rb \
	${BUILDDIR}/pkgdb.rb \
	${BUILDDIR}/pkgdbtools.rb \
	${BUILDDIR}/pkginfo.rb \
	${BUILDDIR}/pkgmisc.rb \
	${BUILDDIR}/pkgtools.rb \
	${BUILDDIR}/pkgtsort.rb \
	${BUILDDIR}/pkgversion.rb \
	${BUILDDIR}/portinfo.rb \
	${BUILDDIR}/ports.rb \
	${BUILDDIR}/portsdb.rb

FILESDIR?=	`${RUBY} -rrbconfig -e \
	'puts "%s/%s.%s" % %w[sitedir MAJOR MINOR].map { |k| Config::CONFIG[k] }'`

CLEANDIRS=	${BUILDDIR}

.for file in ${FILES}
${file}: ${file:T}
	${RUBY} -wc ${.ALLSRC}
	@mkdir -p ${BUILDDIR}
	${RUBY} -p \
		-e 'sub %r:/usr/local:, "${PREFIX}"' \
		${.ALLSRC} > ${.TARGET}
.endfor

.include <bsd.prog.mk>

.include "${.CURDIR}/../Makefile.compat"
