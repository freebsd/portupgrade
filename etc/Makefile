# $Id: Makefile 52 2006-01-01 06:26:59Z koma2 $

ETCDIR?=	${PREFIX}/etc

BUILDDIR=	.build

SCRIPTS=	${BUILDDIR}/status-pkg.sh

#SCRIPTSDIR_status-pkg.sh=	/etc/periodic/weekly
#SCRIPTSNAME_status-pkg.sh=	400.status-pkg.sh
SCRIPTSDIR_status-pkg.sh=	${ETCDIR}
SCRIPTSNAME_status-pkg.sh=	pkgtools.status-pkg.sh

FILES=		pkgtools.conf

FILESDIR?=	${ETCDIR}
FILESNAME_pkgtools.conf=	pkgtools.conf.sample

MANDIR=		${PREFIX}/man/man

MAN5=		pkgtools.conf.5

CLEANDIRS=	${BUILDDIR}

.for script in ${SCRIPTS}
${script}: ${script:T}
	@mkdir -p ${BUILDDIR}
	${RUBY} -p \
		-e 'sub(%r:/usr/local:, "${PREFIX}")' \
		-e 'sub(%r:(/etc/rc\.subr):, "${PREFIX}\\1") if !File.exist?("/etc/rc.subr")' \
		${.ALLSRC} > ${.TARGET}
.endfor

.include <bsd.prog.mk>

.include "${.CURDIR}/../Makefile.compat"
