
PREFIX?=	/usr/local

DOCSDIR?=	${PREFIX}/share/doc/pkgtools
EXAMPLESDIR?=	${PREFIX}/share/examples/pkgtools

RUBY?=		${PREFIX}/bin/ruby
.if empty(RUBY_SITELIBDIR)
RUBY_SITELIBDIR!=	${RUBY} -rrbconfig -e 'puts "%s/%s.%s" % %w[sitedir MAJOR MINOR].map { |k| RbConfig::CONFIG[k] }'
.endif

MKDIR?=		mkdir -p
