$Id: README 52 2006-01-01 06:26:59Z koma2 $

You need to install the following ports to use these pkgtools.

	lang/ruby18		- Ruby 1.8 interpreter
		or
	lang/ruby16		- Ruby 1.6 interpreter
		and
	lang/ruby16-shim-ruby18	- Ruby 1.8 features and modules for 1.6

		and if you want to run tests:

	devel/ruby-testunit	- Unit testing framework

============
portupgrade
============

Portupgrade is a tool to upgrade installed packages via ports or
packages.  It allows you to upgrade installed packages without having
to reinstall dependent/required packages by directly adjusting the
package database located under /var/db/pkg, while it can also upgrade
packages recursively.

e.g.
	portupgrade gtk

============
portinstall
============

Portinstall is equivalent to `portupgrade -N', which means it tries to
install the latest version when a specified package is not installed.
Prior to the installation of a new package, all the required packages
are upgraded.

e.g.
	portinstall shells/zsh

============
portversion
============

Portversion is a tool to compare the versions of install packages with
those in the ports tree.  It is a replacement for pkg_version(1)
cooperative with portupgrade, that is, the command output is optimized
for portupgrade.  Besides, it runs much faster than pkg_version(1)
because it utilizes the prebuilt ports database. (See portsdb)

e.g.
	portversion

============
portsdb
============

Portsdb generates the ports database named INDEX.db from the ports
INDEX file.  It is commonly used among the tool suite and
automatically updated on demand when it gets older than the ports
INDEX file.

e.g.
	portsdb -Uu

============
ports_glob
============

Ports_glob expands ports globs.  It understands wildcards and is
capable of listing the required, dependent or master ports of a given
port.  It would be handy to use from within a shell script.

e.g.
	portsdb -M japanese/linux-netscape47-navigator

============
pkg_fetch
============

Pkg_fetch is a tool to download binary packages from remote sites.  It
can optionally download packages recursively through dependencies.

e.g.
	pkg_fetch -r sawfish

============
pkg_glob
============

Pkg_glob expands package globs.  It understands wildcards and is
capable of listing the required or dependent packages of a package.
It would be handy to use from within a shell script.

e.g.
	pkg_glob -R gnome

============
pkg_deinstall
============

Pkg_deinstall is a wrapper/replacement of pkg_delete(1), which
understands wildcards and is capable of recursing through
dependencies.  It has an option to preserve shared libraries.

e.g.
	pkg_deinstall -r xmms

============
pkgdb
============

Pkgdb creates and updates the packages database which is commonly used
among the tool suite.  It keeps a hash that maps an installed file to
a package name, a hash that maps a package to an origin, and a list of
installed packages.  The database file is automatically updated on
demand when any package is installed or deinstalled after the database
was last updated.

e.g.
	pkgdb -u

Pkgdb also works as an interactive tool for fixing the package
registry database when -F is specified.  It helps you resolve stale
dependencies, unlink cyclic dependencies, complete stale or missing
origins, and remove duplicates.  You have to run this periodically so
that portupgrade and other tools can work effectively and unfailingly.

e.g.
	pkgdb -Fv


============
pkg_which
============

Pkg_which inquires of the packages database which package each given
file came from.  If you do not have permission to update the database
although it is outdated, it delegates tasks to pkg_info(1).

e.g.
	pkg_which patgen

============
portsclean
============

Portsclean is a tool to clean ports working directories, no longer
referenced distfiles, outdated package files, and/or obsolete and
orphan shared libraries.

e.g.
	portsclean -Di

============
portcvsweb
============

Portcvsweb is a tool to instantly browse a history of a given file via
CVSweb.  It may be more useful than you expect.  Try it with src, www,
doc, NetBSD pkgsrc, and OpenBSD ports files. :)

e.g.
	portcvsweb sysutils/portupgrade

-- 
                     /
                    /__  __            Akinori.org / MUSHA.org
                   / )  )  ) )  /     FreeBSD.org / Ruby-lang.org
Akinori MUSHA aka / (_ /  ( (__(  @ iDaemons.org / and.or.jp
