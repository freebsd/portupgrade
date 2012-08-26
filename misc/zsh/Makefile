
FILES=	_pkgtools

.if !defined(ZSH_SITEFNDIR)
ZSH_SITEFNDIR=	${PREFIX}/share/zsh/site-functions
.endif

FILESDIR?=	${ZSH_SITEFNDIR}

beforeinstall:
	${MKDIR} ${DESTDIR}${FILESDIR}

.include <bsd.prog.mk>

.include "${.CURDIR}/../../Makefile.compat"
