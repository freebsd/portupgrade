# $Id: Makefile,v 1.1.1.1 2006/06/13 12:59:00 sem Exp $

FILES=	_pkgtools

.if !defined(ZSH_SITEFNDIR)
ZSH_SITEFNDIR=	${PREFIX}/share/zsh/site-functions
.endif

FILESDIR?=	${ZSH_SITEFNDIR}

beforeinstall:
	${MKDIR} ${FILESDIR}

.include <bsd.prog.mk>

.include "${.CURDIR}/../../Makefile.compat"
