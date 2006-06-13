# $Id: Makefile 52 2006-01-01 06:26:59Z koma2 $

BUILDDIR=	.build

FILES=	${BUILDDIR}/pkg.rb \
	${BUILDDIR}/pkgdb.rb \
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
