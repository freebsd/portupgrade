#
# Copyright (c) 2001-2004 Akinori MUSHA <knu@iDaemons.org>
# Copyright (c) 2006-2008 Sergey Matveychuk <sem@FreeBSD.org>
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id: pkgdb.rb,v 1.14 2008/01/08 11:32:27 sem Exp $

require 'singleton'
require 'pkgtsort'
require 'pkgmisc'
require 'pkgdbtools'

class PkgDB
  include Singleton
  include Enumerable
  include PkgDBTools

  DB_VERSION = [:FreeBSD, 7]
  # :db_version		=> DB_VERSION
  # :pkgnames		=> list of installed packages
  # :origins		=> list of installed packages' origins
  # :mtime		=> modification time (marshalled)
  # ?ori/gin		=> pkgname
  #   ...
  # ?pkgname		=> origin
  #   ...
  # /path/to/file	=> pkgname
  #   ...

  PKGDB_FILES = {
    :contents => '+CONTENTS',
    :comment => '+COMMENT',
    :desc => '+DESC',
    :install => '+INSTALL',
    :post_install => '+POST-INSTALL',
    :deinstall => '+DEINSTALL',
    :post_deinstall => '+POST-DEINSTALL',
    :require => '+REQUIRE',
    :required_by => '+REQUIRED_BY',
    :display => '+DISPLAY',
    :mtree => '+MTREE_DIRS',
    :ignoreme => '+IGNOREME',
  }

  PREFIX = '/usr/local'

  LOCK_FILE = '/var/run/pkgdb.db.lock'

  CMD = {
    :pkg_add			=> nil,
    :pkg_create			=> nil,
    :pkg_delete			=> nil,
    :pkg_info			=> nil,
    :pkg_deinstall		=> "#{PREFIX}/sbin/pkg_deinstall",
    :pkg_fetch			=> "#{PREFIX}/sbin/pkg_fetch",
    :pkg_which			=> "#{PREFIX}/sbin/pkg_which",
    :pkgdb			=> "#{PREFIX}/sbin/pkgdb",
    :portcvsweb			=> "#{PREFIX}/sbin/portcvsweb",
    :portinstall		=> "#{PREFIX}/sbin/portinstall",
    :portsclean			=> "#{PREFIX}/sbin/portsclean",
  }

  def self.command(sym)
    CMD.key?(sym) or raise ArgumentError, "#{sym}: unregistered command"

    full = CMD[sym] and return full

    cmd = sym.to_s

    full = "#{PREFIX}/sbin/#{cmd}"
    File.executable?(full) and return full
    full = "/usr/sbin/#{cmd}"
    File.executable?(full) and return full

    cmd
  end

  class DBError < StandardError
#    def message
#      "pkgdb error"
#    end
  end

  def PkgDB.finalizer
    Proc.new {
      PkgDBTools.remove_lock(LOCK_FILE)
    }
  end

  def initialize(*args)
    @db = nil
    @lock_file = Process.euid == 0 ? LOCK_FILE : nil
    @db_version = DB_VERSION
    ObjectSpace.define_finalizer(self, PkgDB.finalizer)
    setup(*args)
  end

  def setup(alt_db_dir = nil, alt_db_driver = nil)
    set_db_dir(alt_db_dir)
    set_db_driver(alt_db_driver)

    self
  end

  def db_dir=(new_db_dir)
    @abs_db_dir = nil

    @db_dir = File.expand_path(new_db_dir || ENV['PKG_DBDIR'] || '/var/db/pkg')

    @db_file = File.join(@db_dir, 'pkgdb.db')
    @fixme_file = ENV['PKG_FIXME_FILE'] || '/var/db/pkgdb.fixme'
    @db_filebase = @db_file.sub(/\.db$/, '')
    close_db

    @installed_pkgs = nil

    @db_dir
  end
  alias set_db_dir db_dir=

  def abs_db_dir
    unless @abs_db_dir
      dir = db_dir

      begin
	Dir.chdir(dir) {
	  @abs_db_dir = Dir.pwd
	}
      rescue => e
	raise DBError, "Can't chdir to '#{dir}': #{e.message}"
      end
    end

    @abs_db_dir
  end

  def strip(path, installed_only = false)
    base = path.chomp('/')	# allow `pkgname/'

    if base.include?('/')
      if %r"^[^/]+/[^/]+$" =~ base	# "
	if installed_only
	  return deorigin_glob(base) ? base : nil
	else
	  return base
	end
      end

      dir, base = File.split(File.expand_path(base))

      if dir != db_dir && dir != abs_db_dir
	return nil
      end
    end

    if installed_only && !installed?(base)
      return nil
    end

    base
  end

  def pkgdir(pkgname)
    File.join(db_dir, pkgname)
  end

  def pkgdir?(dir)
    File.exist?(File.join(dir, PKGDB_FILES[:contents])) &&
      !File.exist?(File.join(dir, PKGDB_FILES[:ignoreme]))
  end

  def pkgfile(pkgname, filename)
    if filename.kind_of?(Symbol)
      filename = PKGDB_FILES[filename]
    end

    File.join(pkgdir(pkgname), filename)
  end

  def pkg(pkgname)
    installed?(pkgname) and PkgInfo.new(pkgname)
  rescue => e
    return nil
  end

  alias [] pkg

  def origin(pkgname)
    open_db

    @db['?' + pkgname]
  rescue => e
    raise DBError, e.message
  end

  def add_origin(pkgname, origin)
    @installed_ports << origin

    @db['?' + pkgname] = origin

    o_key = '?' + origin
    o_val = @db[o_key]

    if o_val
      o_val = o_val.split << pkgname
      o_val.uniq!		# just in case
      @db[o_key] = o_val.join(' ')
    else
      @db[o_key] = pkgname
    end

    true
  end
  private :add_origin

  def delete_origin(pkgname)
    p_key = '?' + pkgname

    origin = @db[p_key] or
      begin
	STDERR.print "(? #{pkgname})"
	return false
      end

    @db.delete(p_key)

    o_key = '?' + origin

    pkgs = @db[o_key] or
      begin
	STDERR.print "(? #{origin})"
	return false
      end

    pkgs = pkgs.split
    pkgs.delete(pkgname)

    if pkgs.empty?
      @installed_ports.delete(origin)
      @db.delete(o_key)
    else
      @db[o_key] = pkgs.join(' ')
    end

    true
  end
  private :delete_origin

  def set_origin(pkgname, origin)
    update_db

    open_db_for_update!

    delete_origin(pkgname)
    add_origin(pkgname, origin)

    @installed_ports.uniq!
    @installed_ports.sort!

    @db[':mtime'] = Marshal.dump(Time.now)
    @db[':origins'] = @installed_ports.join(' ')

    close_db
  rescue => e
    raise DBError, e.message
  end

  def deorigin(origin)
    open_db

    if str = @db['?' + origin]
      str.split
    else
      nil
    end
  rescue => e
    raise DBError, e.message
  end

  def deorigin_glob(pattern)
    if pattern.is_a?(String) && /[*?\[]/ !~ pattern
      return deorigin(pattern)
    end

    open_db

    ret = []
    @db.each_key do |key|
      /^\?(.*)/ =~ key or next

      origin = $1

      PortInfo.match?(pattern, origin) or next

      if pkgnames = deorigin(origin)
	ret.concat(pkgnames)
      end
    end

    if ret.empty?
      nil
    else
      ret
    end
  rescue => e
    raise DBError, e.message
  end

  def date_db_dir
    File.mtime(db_dir) rescue Time.at(0)
  end

  def up_to_date?
    date_db_file() >= date_db_dir()
  end

  def check_db
    return true if up_to_date? || File.writable?(db_dir)

    if $sudo
      close_db

      if system!(PkgDB::command(:pkgdb), '-u')
	mark_fixme
	return true
      end
    end

    raise DBError, "The pkgdb must be updated.  Please run 'pkgdb -u' as root."
  end

  def update_db(force = false)
    if !force
      up_to_date? and return false
    end

    close_db

    prev_sync = STDERR.sync
    STDERR.sync = true

    rebuild = force || !File.exist?(@db_file)

    STDERR.printf '[%s the pkgdb <format:%s> in %s ... ',
      rebuild ? 'Rebuilding' : 'Updating', @db_driver, db_dir

    @installed_pkgs = installed_pkgs!.freeze

    if rebuild
      open_db_for_rebuild!

      new_pkgs = @installed_pkgs

      deleted_pkgs = []

      @installed_ports = []
    else
      begin
	open_db_for_update!

	s = @db[':origins']
	s.is_a?(String) or raise "origins - not a string (#{s.class})"
	@installed_ports = s.split

	s = @db[':pkgnames']
	s.is_a?(String) or raise "pkgnames - not a string (#{s.class})"
	prev_installed_pkgs = s.split

	new_pkgs = @installed_pkgs - prev_installed_pkgs
	deleted_pkgs = prev_installed_pkgs - @installed_pkgs

	db_mtime = date_db_file()

	(@installed_pkgs & prev_installed_pkgs).each do |pkg|
	  pkg_mtime = date_installed(pkg)

	  if db_mtime < pkg_mtime
	    new_pkgs << pkg
	    deleted_pkgs << pkg
	  end
	end

	deleted_pkgs.sort!
      rescue => e
	STDERR.print "#{e.message}; rebuild needed] "
	return update_db(true)
      end
    end

    STDERR.printf "- %d packages found (-%d +%d) ",
      @installed_pkgs.size, deleted_pkgs.size, new_pkgs.size

    if @installed_pkgs.size == 0
      STDERR.puts " nothing to do]"
      @db[':mtime'] = Marshal.dump(Time.now)
      @db[':origins'] = ' '
      @db[':pkgnames'] = ' '
      @db[':db_version'] = Marshal.dump(DB_VERSION)

      return true
    end

    unless deleted_pkgs.empty?
      STDERR.print '(...)'

      # NOTE: you cannot delete keys while you enumerate the database elements
      @db.select { |path, pkgs|
	path[0] == ?/ && pkgs.split.find { |pkg| deleted_pkgs.qinclude?(pkg) }
      }.each do |path, pkgs|
	path = File.realpath(path)

	pkgs = pkgs.split - deleted_pkgs

	if pkgs.empty?
	  @db.delete(path)
	else
	  @db[path] = pkgs.join(' ')
	end
      end

      deleted_pkgs.each do |pkg|
	delete_origin(pkg)
      end
    end

    n=0
    new_pkgs.sort { |a, b|
      date_installed(a) <=> date_installed(b)
    }.each do |pkg|
      STDERR.putc ?.

      n+=1
      if n % 100 == 0
	STDERR.print n
      end

      begin
	pkginfo = PkgInfo.new(pkg)

	if origin = pkginfo.origin
	  add_origin(pkg, origin)
	end

	pkginfo.files.each do |path|
	  path = File.realpath(path)

	  if @db.key?(path)
	    pkgs = @db[path].split
	    pkgs << pkg if !pkgs.include?(pkg)
	    @db[path] = pkgs.join(' ')
	  else
	    @db[path] = pkg
	  end
	end
      rescue => e
	STDERR.puts "", e.message + ": skipping..."
	next
      end
    end

    @installed_ports.uniq!
    @installed_ports.sort!

    @db[':mtime'] = Marshal.dump(Time.now)
    @db[':origins'] = @installed_ports.join(' ')
    @db[':pkgnames'] = @installed_pkgs.join(' ')
    @db[':db_version'] = Marshal.dump(DB_VERSION)

    STDERR.puts " done]"

    mark_fixme

    true
  rescue => e
    File.unlink(@db_file) if File.exist?(@db_file)
    raise DBError, "#{e.message}: Cannot update the pkgdb!]"
  ensure
    close_db
  end

  def open_db
    @db and return @db

    check_db

    update_db

    retried = false

    begin
      open_db_for_read!

      check_db_version or raise TypeError, 'database version mismatch/bump detected'

      s = @db[':pkgnames']
      s.is_a?(String) or raise TypeError, "pkgnames - not a string (#{s.class})"
      @installed_pkgs = s.split

      s = @db[':origins']
      s.is_a?(String) or raise TypeError, "origins - not a string (#{s.class})"
      @installed_ports = s.split
    rescue TypeError => e
      if retried
	raise DBError, "#{e.message}: Cannot read the pkgdb!"
      end

      STDERR.print "[#{e.message}] "
      update_db(true)

      retried = true
      retry
    end

    @db
  end

  def which_m(path)
    which(path, true)
  end

  def which(path, m = false)
    path = File.realpath(path)

    open_db

    if !@db.key?(path)
      nil
    else
      pkgnames = @db[path].split

      m ? pkgnames : pkgnames.last
    end
  rescue => e
    raise DBError, e.message
  ensure
    close_db
  end

  def date_installed(pkgname)
    installed?(pkgname) or return nil

    File.mtime(pkg_comment(pkgname)) ||
      File.mtime(pkg_descr(pkgname)) ||
      File.mtime(pkg_contents(pkgname)) rescue Time.at(0)
  end

  def installed_pkg?(pkgname)
    installed_pkgs().qinclude?(pkgname)
  end

  alias installed? installed_pkg?

  def installed_port?(origin)
    installed_ports().qinclude?(origin)
  end

  def required?(pkgname)
    file = pkg_required_by(pkgname)

    File.exist?(file) && !File.zero?(file)
  end

  def required_by(pkgname)
    filename = pkg_required_by(pkgname)

    File.exist?(filename) or return nil

    deps = {}

    File.open(filename).each_line { |line|
      line.chomp!
      deps[line] = true unless line.empty?
    }

    deps.keys
  end

  def pkgdep(pkgname, want_deporigins = false)
    filename = pkg_contents(pkgname)

    File.exist?(filename) or return nil

    deps = {}
    prev = nil

    if File.size(filename) >= 65536	# 64KB
      obj = "| grep -E '^@pkgdep|^@comment DEPORIGIN:' #{filename}"
    else
      obj = filename
    end

    open(obj) do |f|
      f.each do |line|
	case line
	when /^@pkgdep\s+(\S+)/
	  prev = $1
	  deps[prev] = nil
	when /^@comment DEPORIGIN:(\S+)/
	  if want_deporigins && prev
	    deps[prev] = $1
	    prev = nil
	  end
	end
      end
    end

    if want_deporigins
      deps
    else
      deps.keys
    end
  end

  PKGDB_FILES.each_key do |key|
    module_eval %{
      def pkg_#{key.to_s}(pkgname)
	pkgfile(pkgname, #{key.inspect})
      end
    }
  end

  def self.parse_date(str)
    require 'parsedate'

    ary = ParseDate.parsedate(str)
    ary.pop
    tz = ary.pop

    case tz
    when 'GMT', 'UTC'
      Time.utc(*ary)
    else
      Time.local(*ary)
    end
  rescue
    raise ArgumentError, "#{str}: date format error"
  end

  def installed_pkgs!()
    Dir.entries(db_dir).select { |pkgname|
      /^\.\.?$/ !~ pkgname && pkgdir?(pkgdir(pkgname))
    }.sort
  rescue => e
    raise DBError, e.message
  end

  def installed_pkgs()
    open_db if @installed_pkgs.nil?

    @installed_pkgs
  end

  def installed_ports!()
    ary = installed_pkgs!.map { |pkgname| origin(pkgname) }
    ary.uniq!
    ary.sort!
    ary
  end

  def installed_ports()
    open_db if @installed_ports.nil?

    @installed_ports
  end

  def glob(pattern = true, want_pkg_info = true)
    list = []
    pkg = nil
    is_origin = false

    case pattern
    when String
      # shortcut
      if pkg = pkg(pattern)
	if block_given?
	  yield(want_pkg_info ? pkg : pattern)
	  return nil
	else
	  return [want_pkg_info ? pkg : pattern]
	end
      end      

      if pattern.include?('/')
	is_origin = true
      elsif /^([<>]=?)(.*)/ =~ pattern
	op = $1
	arg = $2

	pkgs = glob(arg)

	begin
	  if pkgs.empty?
	    base = PkgDB.parse_date(arg)
	  else
	    pkgs.size >= 2 and
	      raise ArgumentError, "#{arg}: ambiguous package specification (#{pkgs.join(', ')})"

	    base = date_installed(pkgs[0].to_s)
	  end

	  pattern = op + base.strftime('%Y-%m-%d %H:%M:%S')
	rescue => e
	  STDERR.puts e.message

	  if block_given?
	    return nil
	  else
	    return []
	  end
	end
      end
    when Regexp
      if pattern.source.include?('/')
	is_origin = true
      end
    end

    if is_origin
      if pkgnames = deorigin_glob(pattern)
	if block_given?
	  pkgnames.each do |pkgname|
	    yield(want_pkg_info ? PkgInfo.new(pkgname) : pkgname)
	  end

	  return nil
	else
	  if want_pkg_info
	    return pkgnames.map { |pkgname| PkgInfo.new(pkgname) }
	  else
	    return pkgnames
	  end
	end
      end

      if block_given?
	return nil
      else
	return []
      end
    end

    installed_pkgs().each do |pkgname|
      pkg = PkgInfo.new(pkgname)

      pkg.match?(pattern) or next

      if block_given?
	yield(want_pkg_info ? pkg : pkgname)
      else
	list.push(want_pkg_info ? pkg : pkgname)
      end
    end

    if block_given?
      nil
    else
      list
    end
  end

  def match?(pattern, pkgname)
    glob(pattern) do |i|
      return true if i == pkgname
    end

    false
  end

  def each(want_pkg_info = true, &block)
    glob(true, want_pkg_info, &block)
  end

  def tsort(pkgnames)
    t = TSort.new

    pkgnames.each do |pkgname|
      deps = pkgdep(pkgname) || []

      t.add(pkgname, *deps)
    end

    t
  end

  def sort(pkgnames)
    tsort(pkgnames).tsort! & pkgnames
  end

  def sort!(pkgnames)
    pkgnames.replace(sort(pkgnames))
  end

  def tsort_build(pkgnames)
    t = TSort.new

    pkgnames.each do |pkgname|
      pkg = pkg(pkgname) or next

      # use package dependencies..
      deps = pkgdep(pkgname) || []

      if origin = pkg.origin
	# ..and ports dependencies
	PortsDB.instance.all_depends_list(origin).each do |o|
	  if bdeps = deorigin(o)
	    deps.concat(bdeps)
	  end
	end
      end

      t.add(pkgname, *deps)
    end

    t
  end

  def sort_build(pkgnames)
    tsort_build(pkgnames).tsort! & pkgnames
  end

  def sort_build!(pkgnames)
    pkgnames.replace(sort_build(pkgnames))
  end

  def fixme_marked?
    File.exist?(@fixme_file)
  end

  def mark_fixme
    fixme_marked? and return

    File.open(@fixme_file, "w").close
  rescue
    system!('/usr/bin/touch', @fixme_file)
  end

  def unmark_fixme
    fixme_marked? or return

    File.unlink(@fixme_file)
  rescue
    system!('/bin/rm', '-f', @fixme_file)
  end

  def autofix(less_quiet = true)
    autofix!(less_quiet) if fixme_marked?
  end

  def autofix!(less_quiet = true)
    xsystem!(PkgDB::command(:pkgdb), '-aFO' << (less_quiet ? 'Q' : 'QQ'))
  end

  def recurse(pkgname, recurse_down = false, recurse_up = false, sanity_check = false)
    list = []

    if recurse_up || sanity_check
      autofix

      deps = pkgdep(pkgname) and deps.each do |name|
	installed?(name) or
	  raise DBError,
	  format("Stale dependency: %s --> %s -- manually run 'pkgdb -F' to fix%s.",
		 pkgname, name,
		 recurse_up ? ' (-O disallowed when -R is given)' : ', or specify -O to force')

	list << name if recurse_up
      end
    end

    list << pkgname

    if recurse_down || sanity_check
      autofix

      deps = required_by(pkgname) and deps.each do |name|
	installed?(name) or
	  raise DBError,
	  format("Stale dependency: %s <-- %s -- manually run 'pkgdb -F' to fix%s.",
		 pkgname, name,
		 recurse_down ? ' (-O disallowed when -r is given)' : ', or specify -O to force')

	list << name if recurse_down
      end
    end

    list
  end
end
