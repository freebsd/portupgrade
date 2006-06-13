# $Id: pkgsqldb.rb 52 2006-01-01 06:26:59Z koma2 $

require 'singleton'
require 'pkgtsort'
require "pkgmisc"

class PkgDB
  include Singleton
  include Enumerable

  DB_VERSION = [:FreeBSD, 1]

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

  CMD = {
    :pkg_add			=> '/usr/sbin/pkg_add',
    :pkg_create			=> '/usr/sbin/pkg_create',
    :pkg_delete			=> '/usr/sbin/pkg_delete',
    :pkg_info			=> '/usr/sbin/pkg_info',
    :make_describe_pass1	=> "#{PREFIX}/sbin/make_describe_pass1",
    :make_describe_pass2	=> "#{PREFIX}/sbin/make_describe_pass2",
    :pkg_deinstall		=> "#{PREFIX}/sbin/pkg_deinstall",
    :pkg_fetch			=> "#{PREFIX}/sbin/pkg_fetch",
    :pkg_which			=> "#{PREFIX}/sbin/pkg_which",
    :pkgdb			=> "#{PREFIX}/sbin/pkgdb",
    :portcvsweb			=> "#{PREFIX}/sbin/portcvsweb",
    :portsclean			=> "#{PREFIX}/sbin/portsclean",
  }

  class DBError < StandardError
#    def message
#      "pkgdb error"
#    end
  end

  def initialize(*args)
    setup(*args)
  end

  def setup(alt_db_dir = nil, alt_db_driver = nil)
    set_db_dir(alt_db_dir)
    set_db_driver(alt_db_driver)

    self
  end

  def db_dir()
    unless @db_dir
      set_db_dir(nil)	# initialize with the default value
    end

    @db_dir
  end

  def db_dir=(new_db_dir)
    @abs_db_dir = nil

    @db_dir = File.expand_path(new_db_dir || ENV['PKG_DBDIR'] || '/var/db/pkg')

    @db_file = File.join(@db_dir, 'pkgdb.sqldb')
    @fixme_file = ENV['PKG_FIXME_FILE'] || "/var/db/pkgdb.fixme"
    close_db

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

  def db_driver()
    unless @db_driver
      set_db_driver(nil)	# initialize with the default value
    end

    @db_driver
  end

  def db_driver=(new_db_driver)
    begin
#      case new_db_driver || ENV['PKG_DBDRIVER'] || 'sqlite'
#      else
	@db_driver = :sqlite
#      end

      case @db_driver
      when :sqlite
	require 'dbi'
      end
    rescue LoadError
      raise DBError, "No driver is available!"
    end

    @db_driver
  end
  alias set_db_driver db_driver=

  def get_meta(key)
    @db.select_one("select #{key} from tbl_meta")[0]
  end

  def set_meta(key, val)
    @db.do("update tbl_meta set #{key} = ? where line = 1", val)
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

    origin, = @db.select_one('select origin from tbl_packages where pkgname = ?',
			     pkgname)

    origin
  rescue => e
    raise DBError, e.message
  end

  def set_origin(pkgname, origin)
    update_db

    open_db_for_update!

    @db.do("insert or replace into tbl_packages values (?, ?, ?)",
	   pkgname, origin, date_installed(pkgname))

    set_meta('mtime', Time.now)

    close_db
  rescue => e
    raise DBError, e.message
  end

  def deorigin(origin)
    open_db

    rows = @db.select_all("select pkgname from tbl_packages where origin = ?",
			  origin)

    if rows.empty?
      nil
    else
      rows.flatten
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

    @db.select_all('select * from tbl_packages') do |pkgname, origin|
      PortInfo.match?(pattern, origin) and ret << pkgname
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

  def date_db_file
    if @db
      mtime = get_meta('mtime').to_time
    elsif File.exist?(@db_file)
      open_db_for_read!
      mtime = get_meta('mtime').to_time
      close_db
    else
      mtime = Time.at(0)
    end

    mtime
  rescue => e
    return Time.at(0)
  end

  def up_to_date?
    date_db_file() >= date_db_dir()
  end

  def check_db_version
    db_version = Marshal.load(get_meta('db_version'))

    db_version[0] == DB_VERSION[0] && db_version[1] >= DB_VERSION[1]
  rescue => e
    return false
  end

  def check_db
    return true if up_to_date? || File.writable?(db_dir)

    if $sudo
      close_db

      if system!(PkgDB::CMD[:pkgdb], '-u')
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

    STDERR.printf '[%s the pkgdb in %s ... ',
      rebuild ? 'Rebuilding' : 'Updating', db_dir

    _installed_pkgs = installed_pkgs!.freeze

    if rebuild
      open_db_for_rebuild!

      new_pkgs = _installed_pkgs

      deleted_pkgs = []
    else
      begin
	open_db_for_update!

	prev_installed_pkgs = installed_pkgs()

	new_pkgs = _installed_pkgs - prev_installed_pkgs
	deleted_pkgs = prev_installed_pkgs - _installed_pkgs

	db_mtime = date_db_file()

	(_installed_pkgs & prev_installed_pkgs).each do |pkg|
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
      _installed_pkgs.size, deleted_pkgs.size, new_pkgs.size

    unless deleted_pkgs.empty?
      STDERR.print '(...)'

      deleted_pkgs.each do |pkg|
	@db.do("delete from tbl_files where pkgname = ?",
	       pkg)

	@db.do("delete from tbl_packages where pkgname = ?",
	       pkg)
      end
    end

    new_pkgs.each do |pkg|
      STDERR.putc ?.

      begin
	pkginfo = PkgInfo.new(pkg)

	mtime = pkginfo.date_installed

	if origin = pkginfo.origin
	  @db.do("insert or replace into tbl_packages values (?, ?, ?)",
		 pkg, origin, mtime)
	end

	pkginfo.files.each do |file|
	  file = File.realpath(file)

	  @db.do("insert into tbl_files values (?, ?, ?)",
		 file, pkg, mtime)
	end
      rescue => e
	STDERR.puts "", e.message + ": skipping..."
	next
      end
    end

    set_meta('mtime', Time.now)
    set_meta('db_version', Marshal.dump(DB_VERSION))
    @db.commit

    STDERR.puts " done]"

    mark_fixme

    true
  rescue => e
    raise DBError, "#{e.message}: Cannot update the pkgdb!]"
  ensure
    close_db
  end

  def open_db_for_read!
    close_db

    @db = DBI.connect("DBI:SQLite:" << @db_file, "", "")
  end

  def open_db_for_update!
    close_db

    @db = DBI.connect("DBI:SQLite:" << @db_file, "", "")
  end

  def open_db_for_rebuild!
    close_db

    File.unlink(@db_file) if File.exist?(@db_file)

    @db = DBI.connect("DBI:SQLite:" << @db_file, "", "")

    @db.do("create table tbl_meta (mtime timestamp, db_version text, line integer)")
    @db.do("insert into tbl_meta values (?, ?, ?)",
	   Time.at(0), Marshal.dump(DB_VERSION), 1)

    @db.do("create table tbl_packages (pkgname text primary key, origin text, mtime timestamp)")
    @db.do("create index idx_packages_origin on tbl_packages (origin)")

    @db.do("create table tbl_files (file text, pkgname text, mtime timestamp)")
    @db.do("create index idx_files_pkgname on tbl_files (pkgname)")
    @db.do("create index idx_files_file on tbl_files (file)")

    @db.commit

    @db
  end

  def open_db
    @db and return @db

    check_db

    update_db

    retried = false

    begin
      open_db_for_read!

      check_db_version or raise TypeError, 'database version mismatch/bump detected'
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

  def close_db
    if @db
      @db.commit
      @db.disconnect
      @db = nil
    end
  end

  def which_m(path)
    which(path, true)
  end

  def which(path, m = false)
    file = File.realpath(path)

    open_db

    rows = @db.select_all("select pkgname from tbl_files where file = ? order by mtime",
			  file)

    if rows.empty?
      nil
    else
      pkgnames = rows.flatten

      m ? pkgnames : pkgnames.last
    end
  rescue => e
    raise DBError, e.message
  end

  def date_installed(pkgname)
    installed?(pkgname) or return nil

    File.mtime(pkg_comment(pkgname)) ||
      File.mtime(pkg_descr(pkgname)) ||
      File.mtime(pkg_contents(pkgname)) rescue Time.at(0)
  end

  def installed_pkg?(pkgname)
    open_db

    @db.select_one("select pkgname from tbl_packages where pkgname = ?",
		   pkgname) ? true : false
  end

  alias installed? installed_pkg?

  def installed_port?(origin)
    open_db

    @db.select_one("select origin from tbl_packages where origin = ?",
		   origin) ? true : false
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

      f.close	# make sure to waitpid the process immediately
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
    Dir.entries(db_dir).select { |pkgname| pkgdir?(pkgdir(pkgname)) }.sort
  rescue => e
    raise DBError, e.message
  end

  def installed_pkgs()
    open_db

    @db.select_all("select pkgname from tbl_packages").flatten
  end

  def installed_ports!()
    ary = installed_pkgs!.map { |pkgname| origin(pkgname) }
    ary.uniq!
    ary.sort!
    ary
  end

  def installed_ports()
    open_db

    @db.select_all("select origin from tbl_packages").flatten
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

  def autofix(less_quiet = false)
    autofix!(less_quiet) if fixme_marked?
  end

  def autofix!(less_quiet = false)
    system!(PkgDB::CMD[:pkgdb], '-aF' << (less_quiet ? 'Q' : 'QQ'))
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
