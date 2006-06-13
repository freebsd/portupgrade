# $Id: Makefile 52 2006-01-01 06:26:59Z koma2 $

SCRIPTSDIR?=	${PREFIX}/sbin

BUILDDIR=	.build

SCRIPTS=	${BUILDDIR}/pkg_fetch \
		${BUILDDIR}/pkg_glob \
		${BUILDDIR}/pkg_sort \
		${BUILDDIR}/pkgdb \
		${BUILDDIR}/portcvsweb \
		${BUILDDIR}/portsclean \
		${BUILDDIR}/portsdb \
		${BUILDDIR}/portupgrade \
		${BUILDDIR}/portversion
LINKS=		${SCRIPTSDIR}/pkg_glob		${SCRIPTSDIR}/pkg_deinstall \
		${SCRIPTSDIR}/pkgdb		${SCRIPTSDIR}/pkg_which \
		${SCRIPTSDIR}/portupgrade	${SCRIPTSDIR}/portinstall \
		${SCRIPTSDIR}/portsdb		${SCRIPTSDIR}/ports_glob

MANDIR=		${PREFIX}/man/man

MAN1=		pkg_deinstall.1 \
		pkg_fetch.1 \
		pkg_glob.1 \
		pkg_sort.1 \
		pkgdb.1 \
		portcvsweb.1 \
		portsclean.1 \
		portsdb.1 \
		portupgrade.1 \
		portversion.1

MLINKS=		pkgdb.1		pkg_which.1 \
		portupgrade.1	portinstall.1 \
		portsdb.1	ports_glob.1

CLEANDIRS=	${BUILDDIR}

.for script in ${SCRIPTS}
${script}: ${script:T}
	${RUBY} -wc ${.ALLSRC}
	@mkdir -p ${BUILDDIR}
	${RUBY} -pe ' \
		if $$. == 1; \
		 if /^#!/; \
		  sub /^#!\s*\S*(\benv\s+)?\bruby/, "#!${RUBY}"; \
		 else; \
		  $$_ = "#!${RUBY}\n" + $$_; \
		 end; \
		end' \
		${.ALLSRC} > ${.TARGET}
.endfor

.include <bsd.prog.mk>

.include "${.CURDIR}/../Makefile.compat"
