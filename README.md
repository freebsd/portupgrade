PKGTOOLS
========

Installation.
-------------

You need to install the following ports to use these pkgtools:

 * `lang/ruby18` -- Ruby 1.8 interpreter, or
 * `lang/ruby19` -- Ruby 1.9 interpreter.

If you want to be able to run tests, you will also need to install
devel/ruby-testunit.

Tools included.
---------------

### portupgrade

Portupgrade is a tool to upgrade installed packages via ports or
packages.  It allows you to upgrade installed packages without having
to reinstall dependent/required packages by directly adjusting the
package database located under /var/db/pkg, while it can also upgrade
packages recursively.

Example: `portupgrade gtk`.

### portinstall

Portinstall is equivalent to `portupgrade -N', which means it tries to
install the latest version when a specified package is not installed.
Prior to the installation of a new package, all the required packages
are upgraded.

Example: `portinstall shells/zsh`.

### portversion

Portversion is a tool to compare the versions of install packages with
those in the ports tree.  It is a replacement for pkg\_version(1)
cooperative with portupgrade, that is, the command output is optimized
for portupgrade.  Besides, it runs much faster than pkg\_version(1)
because it utilizes the prebuilt ports database. (See portsdb)

Example: `portversion`.

### portsdb

Portsdb generates the ports database named INDEX.db from the ports
INDEX file.  It is commonly used among the tool suite and
automatically updated on demand when it gets older than the ports
INDEX file.

Example: `portsdb -Uu`.

### ports\_glob

Ports\_glob expands ports globs.  It understands wildcards and is
capable of listing the required, dependent or master ports of a given
port.  It would be handy to use from within a shell script.

Example: `ports_glob '*/*firefox*'`.

### pkg\_fetch

Pkg_fetch is a tool to download binary packages from remote sites.  It
can optionally download packages recursively through dependencies.

Example: `pkg_fetch -r sawfish`.

### pkg\_glob

Pkg\_glob expands package globs.  It understands wildcards and is
capable of listing the required or dependent packages of a package.
It would be handy to use from within a shell script.

Example: `pkg_glob -R gnome`.

### pkg\_deinstall

Pkg\_deinstall is a wrapper/replacement of pkg\_delete(1), which
understands wildcards and is capable of recursing through
dependencies.  It has an option to preserve shared libraries.

Example: `pkg_deinstall -r xmms`.

### pkgdb

Pkgdb creates and updates the packages database which is commonly used
among the tool suite.  It keeps a hash that maps an installed file to
a package name, a hash that maps a package to an origin, and a list of
installed packages.  The database file is automatically updated on
demand when any package is installed or deinstalled after the database
was last updated.

Example: `pkgdb -u`.

Pkgdb also works as an interactive tool for fixing the package
registry database when -F is specified.  It helps you resolve stale
dependencies, unlink cyclic dependencies, complete stale or missing
origins, and remove duplicates.  You have to run this periodically so
that portupgrade and other tools can work effectively and unfailingly.

Example: `pkgdb -Fv`.

### pkg\_which

Pkg\_which inquires of the packages database which package each given
file came from.  If you do not have permission to update the database
although it is outdated, it delegates tasks to pkg\_info(1).

Example: `pkg_which patgen`.

### portsclean

Portsclean is a tool to clean ports working directories, no longer
referenced distfiles, outdated package files, and/or obsolete and
orphan shared libraries.

Example: `portsclean -Di`.

### portcvsweb

Portcvsweb is a tool to instantly browse a history of a given file via
CVSweb.  It may be more useful than you expect.  Try it with src, www,
doc, NetBSD pkgsrc, and OpenBSD ports files. :)

Example: `portcvsweb sysutils/portupgrade`.
