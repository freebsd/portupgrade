                           ======================
                            NEWS for portupgrade
                           ======================

------------------------------------------------------------------------

portupgrade 2.4.10 (SNAPSHOT)

* List of issues fixed: https://github.com/pkgtools/pkgtools/issues?milestone=4&state=closed
    * All lib files now installed in the pkgtools/ namespace (#23)
    * Fix `portsdb -U` crashing when rebuilding INDEX (#27)
    * Experimental [pkgng](http://github.com/pkgng/pkgng) support (#10)
      * Packages, `pkgdb -F`, `portupgrade -o`  and `port[install|upgrade] -P` are not supported yet.
      * Various -flags do not work with `pkg_deinstall` and `pkgdb`
      * Enable by adding WITH_PKGNG=yes to /etc/make.conf
    * `port[upgrade|install] -v` will show recursive depends.
    * portupgrade now shows the new version installed when completed (#28)
    * Fixed failure being seen as success due to broken script(1) (#8)
      * This only occurs on FreeBSD < 8.1. A working script(1) is now included and installed
        into PREFIX/libexec/pkgtools for older systems.
    * Capture duplicated origins when upgrading and suggest running `pkgdb -F` instead of crashing

portupgrade 2.4.9.5 (released 2012-05-01):

* List of issues fixed: https://github.com/pkgtools/pkgtools/issues?milestone=3&state=closed
    * Fix failed upgrades being seen as success (#25)

portupgrade 2.4.9.4 (released 2012-04-26):

* Portupgrade has a new home: http://pkgtools.github.com
* List of issues fixed: https://github.com/pkgtools/pkgtools/issues?milestone=1&state=closed
    * Fix upgrading to ruby19 causing pkgdb error (db will be rebuilt if it cannot be read)
    * Fix `portrevision -r`
    * Fix `pkgdb -F` losing DEPORIGIN in +CONTENTS for dependent packages
    * Fix `portupgrade -a` crashing with bsdpan packages installed
    * Updated shell completions for bash and zsh

portupgrade 2.4.9.3 (released 2011-08-23):

* Bugfixes.

portupgrade 2.4.9.2 (released 2011-08-22):

* Bugfixes.

portupgrade 2.4.9.1 (released 2011-08-22):

* Ruby 1.9 related bugfixes.

portupgrade 2.4.9 (released 2011-08-18):

* Ruby 1.9 compatibility.

portupgrade 2.4.8 (released 2010-11-23):

* Bugfixes.

portupgrade 2.4.7 (released 2010-11-08):

* Bugfixes.

portupgrade 2.4.6 (released 2008-07-11):

* Fix man pages install.

portupgrade 2.4.5 (released 2008-07-10):

* [portversion, portversion.1] Document new options.

* [pkgtools.rb] Do not touch +CONTENTS file if it's not necessary.

* [pkgmisc.rb] Remove temporary dir with `rm -r'. It could be inner dirs there.

* [pkgdu] A new utility to display disk usage of installed packages.

portupgrade 2.4.4 (released 2008-07-01):

* [pkgtools.rb] Close +CONTENTS file. It made a few problems before.

* [portupgrade.1] Some leftovers removed. Fix .Pp tag.

* [portupgrade] Fix a failure when -PP specified for some ports.

* [portversion] Add -F to show a package full name (with a version number)
  -o to show an origin of a package and -q for quiet output.

* [portupgrade, pkgmisc.rb] Fix a bug in make arguments quoting. If you
  had an argument with spaces (e.g. WITH_MODULES="module1 module2"), it
  was parsed wrong.

* [portupgrade] Allow upgrade dependencies if -R or -r options specified
  but main port is up-to-date.

* [pkgdb.rb, portsdb.rb] If DB can't be updated, remove it and try again.

* [portupgrade] setproctitle with a port name when 'make config' runs.

* [portupgrade] If 'make config' fails, show a warning and ignore it.

* [pkgdb] Do not show 'You do not own pkgdb dir' for root.

portupgrade 2.4.3 (released 2008-02-11):

* [portupgrade] Fix dependencies list after we gather it. So we will not
  try to upgrade dependecies when a specified port is up-to-date.

* [portsclean] Fix a typo in a condition. Now it's work again.

* [portupgrade] Change a semantic of -q option. Now it means 'quiet'.
  Don't show a message when -N specified and there is already installed
  package. (For Peter Hofer. DesktopBSD).

portupgrade 2.4.2 (released 2008-02-04):

* A few bugs was fixed.

portupgrade 2.4.1 (released 2008-01-29):

* Bugs fix releasse.

* [portupgrade] Throw RecursiveDependencyError exception instead of
  plain ruby error.

portupgrade 2.4.0 (released 2008-01-26):

* [portupgrade] All dependencies run under portupgrade control now.

* [portupgrade] -c and -C options was changed. Now portupgrade
  run `make config-conditional` and `make config` accordingly.

* [pkgdb] Bug fix: remove +REQUIRED_BY file if there are no ports
  require this one.

portupgrade 2.3.2 (released 2008-01-13):

* Bugs fix release

portupgrade 2.3.1 (released 2007-07-03):

* [portupgrade] [pkgbd] Many bug fixes related to the last xorg update
  to 7.2.0

portupgrade 2.3.0 (released 2007-03-01):

* [portupgrade] At last all dependencies are tracked by portupgrade.

portupgrade 2.2.6 (released 2007-02-27):

* [pkgdb] Fix -O option parsing.

* [portsdb.db] Fix and update language specific categories list.

* [pkgdb] When run as pkg_which, don't check file existence. It allows to check
  against accidently removed files. (Asked by skv@).

* [pkgdb] Fix a bug when only origins worked in ALT_PKGDEP. pkgname globs
  are very helpful there. (e.g. 'mysql*-server' => 'mysql40-server').

portupgrade 2.2.5 (released 2007-02-26):

* [pkgdb] Fix issues with ghostscript-afpl vs. ghostscript-gnu,
  apache13 vs. apache13+mod-ssl, etc. when -F or -L. The ports must be
  described in ALT_PKGDEP section of pkgtools.conf.

* [pkgdb] Do not make broken pkgdb.db if no ports installed. nanobsd needs it.
  (Asked by Nick Hibma <n_hibma@...>)

* [pkgdb.rb] Speed-up autofix() - add -O option for pkgdb -aF execution.

* [pkgtools.conf] Describe PKG_SUFX variable. (Submitted by Pavel Gubin).

portupgrade 2.2.4 (released 2007-02-23):

* [pkgdb] Fix a bug when some dependencies could lost.

* [pkgdb] -L to allow users fix dependencies those was lost with the bug
  mentioned above.

* [pkgdb] -i turns interactive mode on.

* [pkgdb] Add -O option to turn off dependencies check instead of
  -d option, that turned it on.

portupgrade 2.2.3 (released 2007-02-16, never released in ports):

* Fixes reflected last changes in the ports tree.

* Hide pkgdb -F smartness under -d switch. It makes life harder when
  there are a lot of ports with a lot of depends. (Asked by marcus@).

portupgrade 2.2.2 (released 2006-11-18):

* Add UPGRADE_PORT_VER environment variable. Discussed with DougB@ and
  skv@.

* Add description of UPGRADE_* environment variables in a portupgrade
  man page.

* Add checking size of a lock file before trying read it. It protects us
  from a ruby error if the file is empty by some reason.
  (Reported by: Lowell Gilbert <freebsd-ports-local@be-well.ilk.org>)

portupgrade 2.2.1 (released 2006-11-12):

* Raise an error when MOVED file has a wrong format instead of a weird
  ruby error. (Reported by kris@FreeBSD.org).

* Fix a bug when -P always treated as -PP.

* Change PORT_UPGRADE environment variable with UPGRADE_PORT (contains
  a package name for updating port) and UPGRADE_TOOL=portupgrade.
  Discussed with skv@FreeBSD.org and DougB@FreeBSD.org.

portupgrade 2.2.0 (released 2006-11-06):

* Respect INDEXDIR after fetching INDEX (Andrew Pantyukhin <sat@FreeBSD.org>)

* Add --batch opition.

* Add --without-env-upgrade option.

* Remove -DPACKAGE_BUILDING (it was in fetch-only mode) because it's only
  for build cluster, not users. (Pointed out by kris@FreeBSD.org)

* Add detection of stale lock files. They can stay if one of tools suddenly
  terminated.

* Improve pkgdb -F - respect OPTIONS and pkgtools.conf settings.

portupgrade 2.1.7 (released 2006-08-14):

* Make fetch(1) quiet if stdout is not a tty.

* Highlight summary messages with '**'.

* Extract common code from pkgdb.rb and portdb.rb in pkgdbtools.rb.
  So we have a common open/locking/close etc. procedures for both DBs.

* Do not remove +REQUIRED_BY files when they are empty. pkg_delete(1)
  works this way. (Requested by: Jeremy Messenger <mezz@FreeBSD.org>,
  Doug Barton <dougb@FreeBSD.org>)

* Bugs fixes.

portupgrade 2.1.6 (released 2006-07-23):

* Move all man pages into own one directory for easier maintain.

* Bugs fixes.

portupgrade 2.1.5 (released 2006-07-01):

* Try bdb driver first. If it's failed fall back to bdb1 and dbd afterwards.
  Before the chain was bdb1->dbd, no bdb driver tried.

* Disable running config for all ports. It should be moved to after
  depedencies parsing and dependencies parsing should be rerun after config.

* Fix portupgrade work when stdin closed. It allows to run portupgrade from
  wrappers.

* Do not lock pkgdb.db when runned not as root. No writting possible
  anyway.

* Other bugs fixes.

portupgrade 2.1.4 (released 2006-06-18):

* Add -e (--emit-summaries) option and show summary messages only when
  the option defined or verbose mode is on.

* Allow origins in ALT_PKGDEP. This announced in pkgtools.conf
  but did not work really.

* Run 'make config' before all operations unless -j (--jet-mode)
  option specified.

* Add lock on operations with pkgdb.db. Now you can safe run a few
  portupgrade(1).

* Bugs fixes.

portupgrade 2.1.3 (released 2006-06-11):

* Add ALT_INDEX array to pkgtools.conf. The array holds additional
  INDEX files. It's useful for local categories.

* Add to pkgtools.conf a new dirrective: include_hash('glob').
  It downloads keys and values from files coincided with 'glob'
  and returns a filled hash. The glob is related to PREFIX.

* Add a summary messages on each upgrade/install transaction:
  how many tasks and how many task done.

portupgrade 2.1.2 (released 2006-06-07):

* Set both make argument and environment variable to PORT_UPGRADE=yes.
  It makes possible a port or a package (via install/deinstall scripts)
  to detect if it builds/installs/deinstalls under portupgrade(1)

* Add to pkgtools.conf a new directive: include_eval('file')
  The file will included and evaluated in the place where encountered.
  The file path looking inside of PREFIX.

* Add ALT_MOVED array to pkgtools.conf. The array holds alternate MOVED file.
  E.g. for files in EXTRA_CATEGORIES.

* Make pkgdb offer install a stale dependency before selecting it from
  installed.

portupgrade 2.1.1 (released 2006-06-04):

* Allow set MAKE_ENV in pkgtools.conf. It works like MAKE_ARGS but sets
  environment variables.

* Add firefox in a browser list in portcvsweb(1)

* Add PKG_BACKUP_DIR environment variable to set a directory where
  old package will keep (when '-b' specified). Default: PKG_PATH

* Other bugs fixes.

portupgrade 2.1.0 (released 2006-06-01):

* Rewrite version checking. Now it's complete compliant with pkg_version(1)
  Add mode test in tests/test_pkgversion.rb

* Make tests/test_pkgdb.rb does not depend on libtool with specific version.
  Make it depends on ruby port with dynamicaly getting of its full package name.

* Fix a pointyhat URL. Get rid on bento.freebsd.org URL and alpha platform.

* Other bugs fixes.

portupgrade 2.0.1 (released 2006-01-03):

* portversion(1) also reads MOVED and trace origin change,
  and, when invoked with "-v", displays the new origin.

  Example:

      % portversion -v screen
      screen-4.0.2_2   <  needs updating (port has 4.0.2_3) (=> 'sysutils/screen')

* Add "--ignore-moved" to portupgrade(1) and portversion(1).
  When invoked with this option, both programs totally ignore MOVED.
  If you encounter strange behaviour of these programs, try this out.

* Add IGNORE_MOVED option to pkgtools.conf.
  This can be used to selectively ignore MOVED by pkgs.
  See pkgtools.conf.sample for details.

* Keep the order of MOVED entries, and do not trace back to old entries.
  Previously, when encounters the following entries,

	editors/emacs|editors/emacs19|2004-03-20|emacs 19.x moved to a non-default port location
	editors/emacs21|editors/emacs|2004-03-20|emacs 21.x moved to default port location

  portupgrade traces as "editors/emacs21" -> "editors/emacs" -> "editors/emacs19".
  I thought this behavior should not be what we want to, so added this change.


------------------------------------------------------------------------

portupgrade 2.0.0 (released 2006-01-01):

* Change the versioning scheme of portupgrade.
  portupgrade now becomes 2.0.0!

* Add FreshPorts support to portcvsweb(1).
  You can view CVS history via FreshPorts instead of CVSweb
  by using "portcvsweb -F". See the man page of portcvsweb(1) for details.

* If the change of the origin is written in MOVED,
  portupgrade reads and chases it.
  You no longer need to supply the origin of the new pkg by "-o" option.

  Example:

      When ftp/wget-devel is moved to ftp/wget, previously you had to run,
	  % portupgrade -o ftp/wget wget

      Now, just run

	  % portupgrade wget

      and portupgrade will do what you want to do.

* Try to guess the pkg to be upgraded, when no pkgname is supplied
  as a command line argument.
  This can be done only when the current directory is under $PORTSDIR.

  Example:

      Running

	  % cd /usr/ports/ftp/wget
	  % portupgrade

      will upgrade ftp/wget.

* The frequency of INDEX generation on official site is now sufficient,
  recommend to run "portsdb -F" (fetch INDEX from official site)
  instead of "portsdb -U" (make INDEX by yourself) in portsdb(1). [1]

  Pointed out by: Enrique Matias <cronopios at gmail dot com> [1]

$FreeBSD: projects/pkgtools/NEWS,v 1.29 2011-08-18 07:39:58 stas Exp $
