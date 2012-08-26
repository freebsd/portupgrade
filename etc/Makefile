
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

CLEANDIRS=	${BUILDDIR}

.for script in ${SCRIPTS}
${script}: ${script:T}
	@${MKDIR} ${BUILDDIR}
	${RUBY} -p \
		-e '$$_.sub(%r:/usr/local:, "${PREFIX}")' \
		-e '$$_.sub(%r:(/etc/rc\.subr):, "${PREFIX}\\1") if !File.exist?("/etc/rc.subr")' \
		${.ALLSRC} > ${.TARGET}
.endfor

.include <bsd.prog.mk>

.include "${.CURDIR}/../Makefile.compat"
