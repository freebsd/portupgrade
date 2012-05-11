# vim: set sts=2 sw=2 ts=8 et:
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
# $Id: portsdb.rb,v 1.15 2008/01/08 11:32:27 sem Exp $
# $FreeBSD: projects/pkgtools/lib/portsdb.rb,v 1.17 2011-07-25 12:34:43 swills Exp $

require 'singleton'
require 'tempfile'
require 'pkgtools/pkgmisc'
require 'pkgtools/pkgdbtools'

class PortsDB
  include Singleton
  include Enumerable
  include PkgDBTools

  DB_VERSION = [:FreeBSD, 3]

  LANGUAGE_SPECIFIC_CATEGORIES = {
    "arabic"		=> "ar-",
    "chinese"		=> "zh-",
    "french"		=> "fr-",
    "german"		=> "de-",
    "hebrew"		=> "iw-",
    "hungarian"		=> "hu-",
    "japanese"		=> "ja-",
    "korean"		=> "ko-",
    "polish"		=> "pl-",
    "portuguese"	=> "pt-",
    "russian"		=> "ru-",
    "ukrainian"		=> "uk-",
    "vietnamese"	=> "vi-",
  }

  MY_PORT = 'ports-mgmt/portupgrade'

  LOCK_FILE = '/var/run/portsdb.lock'

  attr_accessor :ignore_categories, :extra_categories, :moved

  class IndexFileError < StandardError
#    def message
#      "index file error"
#    end
  end

  class IndexFileFetchError< IndexFileError
#    def message
#      "index file fetch error"
#    end
  end

  class DBError < StandardError
#    def message
#      "database file error"
#    end
  end

  class MOVEDError < StandardError
#    def message
#      "MOVED file error"
#    end
  end

  class MovedElement
    attr_reader :to, :date, :why, :seq
    def initialize(to, date, why, seq)
      @to = to
      @date = date
      @why = why
      @seq = seq
    end
  end

  class Moved
    MOVED_FILE = 'MOVED'

    def initialize(ports_dir)
      @moved = Hash.new
      @seq = 0
      fill(File.join(ports_dir, MOVED_FILE))
    end

    def fill(moved_file)
      if File.exist?(moved_file)
	File.open(moved_file) do |f|
	  f.each do |line|
	    next if /^[#[:space:]]/ =~ line

	    moved_from, moved_to, date, why = line.chomp.split('|')

	    if moved_from.nil? || moved_to.nil? || date.nil? || why.nil?
	      raise MOVEDError, "MOVED file format error"
	    end

	    moved_to.empty? and moved_to = nil

	    @moved[moved_from] = MovedElement.new(moved_to, date, why, @seq)
	    @seq += 1
	  end
	end
      end
    end

    def trace(port)
      t = []
      me = port

      while true
	if moved = @moved[me]
	  t << moved if t.empty? or t.last.seq < moved.seq
	  if me.nil? or t.map{|p| p.to}.include?(me)
	    break
	  else
	    me = moved.to
	  end
	else
	  break
	end
      end

      if t.empty?
	nil
      else
	t
      end
    end
  end

  def PortsDB.finalizer
    Proc.new {
      PkgDBTools.remove_lock(LOCK_FILE)
    }
  end

  def setup(alt_db_dir = nil, alt_ports_dir = nil, alt_db_driver = nil)
    @db = nil
    @lock_file = Process.euid == 0 ? LOCK_FILE : nil
    @db_version = DB_VERSION
    ObjectSpace.define_finalizer(self, PortsDB.finalizer)
    set_ports_dir(alt_ports_dir)
    set_db_dir(alt_db_dir)
    set_db_driver(alt_db_driver)

    @categories = nil
    @virtual_categories = nil
    @ignore_categories = []
    @extra_categories = []
    @origins = nil
    @pkgnames = nil
    @origins_by_categories = {}
    @ports = {}
    @localbase = nil
    @x11base = nil
    @pkg_sufx = nil
    @moved = Moved.new(ports_dir)

    self
  end

  def make_var(var, dir = ports_dir())
    if var.is_a?(Array)
      vars = var.join(' -V ')
      `cd #{dir} && make -V #{vars} 2>/dev/null`.lines.map { |val|
	val.strip!
	if val.empty?
	  nil
	else
	  val
	end
      }
    else
      val = `cd #{dir} && make -V #{var} 2>/dev/null`.strip
      if val.empty?
	nil
      else
	val
      end
    end
  end

  def ports_dir()
    unless @ports_dir
      set_ports_dir(nil)	# initialize with the default value
    end

    @ports_dir
  end

  def ports_dir=(new_ports_dir)
    @abs_ports_dir = @index_file = @dist_dir = nil
    @alt_index_files = Array.new

    @ports_dir = new_ports_dir || ENV['PORTSDIR'] || '/usr/ports'
  end
  alias set_ports_dir ports_dir=

  def abs_ports_dir()
    unless @abs_ports_dir
      dir = ports_dir

      begin
	Dir.chdir(dir) {
	  @abs_ports_dir = Dir.pwd
	}
      rescue => e
	raise DBError, "Can't chdir to '#{dir}': #{e.message}"
      end
    end

    @abs_ports_dir
  end

  def index_file()
    unless @index_file
      indexdir, indexfile = make_var(['INDEXDIR', 'INDEXFILE'])
      @index_file = ENV['PORTS_INDEX'] || File.join(indexdir, indexfile || 'INDEX')
      @alt_index_files = config_value(:ALT_INDEX) || []
    end

    @index_file
  end

  def db_dir=(new_db_dir)
    @db_dir = new_db_dir || ENV['PORTS_DBDIR'] || ports_dir

    @db_filebase = File.join(@db_dir, File.basename(index_file()))
    @db_file = @db_filebase + '.db'

    close_db

    @db_dir
  end
  alias set_db_dir db_dir=

  def db_dir_list()
    [
      db_dir,
      ports_dir,
      PkgDB.instance.db_dir,
      ENV['TMPDIR'],
      '/var/tmp',
      '/tmp'
    ].compact
  end

  def my_port
    MY_PORT
  end

  def my_portdir
    portdir(MY_PORT)
  end

  def localbase
    @localbase ||= make_var('LOCALBASE', my_portdir) || '/usr/local'
  end

  def x11base
    @x11base ||= make_var('X11BASE', my_portdir) || '/usr/X11R6'
  end

  def pkg_sufx
    @pkg_sufx ||= pkg_sufx!
  end

  def pkg_sufx!
    make_var('PKG_SUFX', my_portdir) || ENV['PKG_SUFX'] || '.tbz'
  end

  def dist_dir()
    @dist_dir ||= make_var('DISTDIR') || portdir('distfiles')
  end

  def join(category, port)
    File.join(category, port)
  end

  def split(origin)
    if %r"^([^./A-Z][^/]*)/([^./][^/]*)$" =~ path
      return $1, $2
    end

    nil
  end

  def strip(path, existing_only = false)
    # handle sequences of /'s (tr_s is not multibyte-aware, hence gsub)
    path = path.gsub(%r"//+", '/')

    %r"^(?:(/.+)/)?([^./][^/]*/[^./][^/]*)/?$" =~ path or return nil

    dir = $1
    port = $2

    if dir && dir != ports_dir && dir != abs_ports_dir
      return nil
    end

    if existing_only && !exist?(port)
      return nil
    end

    port
  end

  def portdir(port)
    File.join(ports_dir, port)
  end

  def subdirs(dir)
    %x"fgrep SUBDIR #{dir}/Makefile | sed -e 's/SUBDIR +=//'
       2> /dev/null".split.select { |i|
      File.directory?(File.join(dir, i))
    }.sort
  end

  def categories
    open_db if @categories.nil?

    @categories
  end

  def real_categories!
    subdirs(ports_dir)
  end

  def categories!
    customize_categories(real_categories!)
  end

  def customize_categories(cats)
    ((cats | @extra_categories) - @ignore_categories).sort
  end

  def category?(category)
    @categories.qinclude?(category)
  end

  def virtual_categories
    open_db if @virtual_categories.nil?

    @virtual_categories
  end

  def virtual_category?(category)
    @virtual_categories.qinclude?(category)
  end

  def ignore_category?(category)
    @ignore_categories.qinclude?(category)
  end

  def update(fetch = false)
    if fetch
      STDERR.print "Fetching the ports index ... "
    else
      STDERR.print "Updating the ports index ... "
    end

    STDERR.flush

    t = Tempfile.new('INDEX')
    t.close
    tmp = t.path

    if File.exist?(index_file)
      if !File.writable?(index_file)
	STDERR.puts "index file #{index_file} not writable!"
	raise IndexFileError, "index generation error"
      end
    else
      dir = File.dirname(index_file)

      if !File.writable?(dir)
	STDERR.puts"index file directory #{dir} not writable!"
	raise IndexFileError, "index generation error"
      end
    end

    if fetch
      system "cd #{abs_ports_dir} && make fetchindex && cp #{index_file} #{tmp}"
    else
      system "cd #{abs_ports_dir} && make INDEXFILE=INDEX.tmp index && mv INDEX.tmp #{tmp}"
    end

    if File.zero?(tmp)
      if fetch
        STDERR.puts 'failed to fetch INDEX!'
        raise IndexFileFetchError, "index fetch error"
      else
        STDERR.puts 'failed to generate INDEX!'
        raise IndexFileError, "index generation error"
      end
    end

    begin
      File.chmod(0644, tmp)
    rescue => e
      STDERR.puts e.message
      raise IndexFileError, "index chmod error"
    end

    if not system('/bin/mv', '-f', tmp, index_file)
      STDERR.puts 'failed to overwrite #{index_file}!"'
      raise IndexFileError, "index overwrite error"
    end

    STDERR.puts "done"

    @categories = nil
    @virtual_categories = nil
    @origins = nil
    @pkgnames = nil
    @origins_by_categories = {}
    @ports = {}

    close_db
  end

  def open_db
    @db and return @db

    update_db

    retried = false

    begin
      open_db_for_read!

      check_db_version or raise TypeError, 'database version mismatch/bump detected'

      s = @db[':categories']
      s.is_a?(String) or raise TypeError, "missing key: categories"
      @categories = s.split

      s = @db[':virtual_categories']
      s.is_a?(String) or raise TypeError, "missing key: virtual_categories"
      @virtual_categories = s.split

      s = @db[':origins']
      s.is_a?(String) or raise TypeError, "missing key: origins"
      @origins = s.split

      s = @db[':pkgnames']
      s.is_a?(String) or raise TypeError, "missing key: pkgnames"
      @pkgnames = s.split.map { |n| PkgInfo.new(n) }

      @origins_by_categories = {}
      (@categories + @virtual_categories).each do |c|
	s = @db['?' + c] and @origins_by_categories[c] = s.split
      end
    rescue => e
      if retried
	raise DBError, "#{e.message}: Cannot read the portsdb!"
      end

      STDERR.print "[#{e.message}] "
      update_db(true)

      retried = true
      retry
    end

    @ports = {}

    @db
  rescue => e
    STDERR.puts e.message
    raise DBError, 'database file error'
  end

  def date_index
    latest_mtime = File.mtime(index_file) rescue nil
    @alt_index_files.each do |f|
      mt = File.mtime(f)
      latest_mtime = mt if mt > latest_mtime
    end
    latest_mtime
  end

  def date_db
    File.mtime(@db_file) rescue nil
  end

  def up_to_date?
    d1 = date_db() and d2 = date_index() and d1 >= d2
  end

  def select_db_dir(force = false)
    return db_dir if File.writable?(db_dir)

    db_dir_list.each do |dir|
      set_db_dir(dir)

      !force && up_to_date? and return dir

      File.writable?(dir) and return dir
    end

    nil
  end

  def update_db(force = false)
    if not File.exist?(index_file)
      begin
        update(true)
      rescue IndexFileFetchError
        update(false)
      end
    end

    !force && up_to_date? and return false

    close_db

    select_db_dir(force) or raise "No directory available for portsdb!"

    prev_sync = STDERR.sync
    STDERR.sync = true

    STDERR.printf "[Updating the portsdb <format:%s> in %s ... ", db_driver, db_dir

    nports = `wc -l #{index_file}`.to_i
    @alt_index_files.each do |f|
      nports += `wc -l #{f}`.to_i
    end

    STDERR.printf "- %d port entries found ", nports

    i = -1

    @origins = []
    @pkgnames = []

    try_again = false
    begin
      open_db_for_rebuild!

      index_files = shelljoin(index_file) + ' '
      index_files.concat(@alt_index_files.join(' '))

      open("| sort #{index_files}", 'r:utf-8') do |f|
	f.each_with_index do |line, i|
	  lineno = i + 1

	  if lineno % 100 == 0
	    if lineno % 1000 == 0
	      STDERR.print lineno
	    else
	      STDERR.putc(?.)
	    end
	  end

	  begin
	    port_info = PortInfo.new(line)

	    next if ignore_category?(port_info.category)

	    origin = port_info.origin
	    pkgname = port_info.pkgname

	    port_info.categories.each do |category|
	      if @origins_by_categories.key?(category)
		@origins_by_categories[category] << origin
	      else
		@origins_by_categories[category] = [origin]
	      end
	    end
	    
	    @ignore_categories.each do |category|
	      @origins_by_categories.delete(category)
	    end

	    @origins << origin
	    @pkgnames << pkgname

	    @db[origin] = port_info
	    @db[pkgname.to_s] = origin
	  rescue => e
	    STDERR.puts index_file + ":#{lineno}:#{e.message}"
	  end
	end
      end

      STDERR.print ' '

      real_categories = real_categories! | @extra_categories
      all_categories = @origins_by_categories.keys

      @categories = (real_categories - @ignore_categories).sort
      @virtual_categories = (all_categories - real_categories).sort

      @db[':categories'] = @categories.join(' ')
      STDERR.putc(?.)
      @db[':virtual_categories'] = @virtual_categories.join(' ')
      STDERR.putc(?.)
      @db[':origins'] = @origins.join(' ')
      STDERR.putc(?.)
      @db[':pkgnames'] = @pkgnames.map { |n| n.to_s }.join(' ')
      STDERR.putc(?.)
      all_categories.each do |c|
	@db['?' + c] = @origins_by_categories[c].join(' ')
      end
      STDERR.putc(?.)
      @db[':db_version'] = Marshal.dump(DB_VERSION)
    rescue => e
      if File.exist?(@db_file)
	begin
	  STDERR.puts " error] Remove and try again."
	  File.unlink(@db_file)
	  try_again = true
	rescue => e
	  raise DBError, "#{e.message}: Cannot update the portsdb! (#{@db_file})]"
	end
      else
	raise DBError, "#{e.message}: Cannot update the portsdb! (#{@db_file})]"
      end
    ensure
      close_db
    end

    if try_again
      update_db(force)
    else
      STDERR.puts " done]"
      STDERR.sync = prev_sync
      true
    end

  end

  def port(key)
    key.is_a?(PortInfo) and return key

    @ports.key?(key) and return @ports[key]

    open_db

    if key.include?('/')
      val = @db[key]
    elsif val = @db[key]
      return port(val)
    end

    @ports[key] = if val then PortInfo.new(val) else nil end
  end
  alias [] port

  def ports(keys)
    keys.map { port(key) }
  end

  alias indices ports

  def origin(key)
    if p = port(key)
      p.origin
    else
      nil
    end
  end

  def origins(category = nil)
    open_db

    if category
      @origins_by_categories[category]
    else
      @origins
    end
  end

  def origins!(category = nil)
    if category
      # only lists the ports which primary category is the given category
      subdirs(portdir(category)).map { |i|
	File.join(category, i)
      }
    else
      list = []

      categories!.each do |i|
	list.concat(origins!(i))
      end

      list
    end
  end

  def each(category = nil)
    ports = origins(category) or return nil

    ports.each { |key|
      yield(@db[key])
    }
  end

  def each_category
    categories.each { |key|
      yield(key)
    }
  end

  def each_origin(category = nil)
    ports = origins(category) or return nil

    ports.each { |key|
      yield(key)
    }
  end

  def each_origin!(category = nil, &block)
    if category
      # only lists the ports which primary category is the given category
      subdirs(portdir(category)).each do |i|
	block.call(File.join(category, i))
      end
    else
      categories!.each do |i|
	each_origin!(i, &block)
      end
    end
  end

  def each_pkgname
    open_db

    @pkgnames.each { |key|
      yield(key)
    }
  end

  def glob(pattern = '*')
    list = []
    pkg = nil

    open_db

    case pattern
    when Regexp
      is_port = pattern.source.include?('/')
    else
      if /^[<>]/ =~ pattern
	raise "Invalid glob pattern: #{pattern}"
      end

      is_port = pattern.include?('/')

      # shortcut
      if portinfo = port(pattern)
	if block_given?
	  yield(portinfo)
	  return nil
	else
	  return [portinfo]
	end
      end
    end

    if is_port
      @origins.each do |origin|
	case pattern
	when Regexp
	  next if pattern !~ origin
	else
	  next if not File.fnmatch?(pattern, origin, File::FNM_PATHNAME)
	end

	if portinfo = port(origin)
	  if block_given?
	    yield(portinfo)
	  else
	    list.push(portinfo)
	  end
	end
      end
    else
      @pkgnames.each do |pkgname|
	next if not pkgname.match?(pattern)

	if portinfo = port(pkgname.to_s)
	  if block_given?
	    yield(portinfo)
	  else
	    list.push(portinfo)
	  end
	end
      end
    end

    if block_given?
      nil
    else
      list
    end
  rescue => e
    STDERR.puts e.message

    if block_given?
      return nil
    else
      return []
    end
  end

  def exist?(port, quick = false)
    return if %r"^[^/]+/[^/]+$" !~ port

    dir = portdir(port)

    return false if not File.file?(File.join(dir, 'Makefile'))

    return true if quick

    make_var('PKGNAME', dir) || false
  end

  def all_depends_list!(origin, before_args = nil, after_args = nil)
    `cd #{$portsdb.portdir(origin)} && #{before_args || ''} make #{after_args || ''} all-depends-list`.lines.map { |line|
      strip(line.chomp, true)
    }.compact
  end

  def all_depends_list(origin, before_args = nil, after_args = nil)
    if !before_args && !after_args && i = port(origin)
      i.all_depends.map { |n| origin(n) }.compact
    else
      all_depends_list!(origin, before_args, after_args)
    end
  end

  def masters(port)
    dir = portdir(port)

    ports = []

    `cd #{dir} ; make -dd -n 2>&1`.each do |line|
      if /^Searching for .*\.\.\.Caching .* for (\S+)/ =~ line.chomp
	path = File.expand_path($1)

	if (path.sub!(%r"^#{Regexp.quote(ports_dir)}/", '') ||
	    path.sub!(%r"^#{Regexp.quote(abs_ports_dir)}/", '')) &&
	    %r"^([^/]+/[^/]+)" =~ path
	  x = $1

	  ports << x if exist?(x) && !ports.include?(x)
	end
      end
    end

    ports.delete(port)

    ports
  end

  def latest_link(port)
    dir = portdir(port)

    flag, name = make_var(['NO_LATEST_LINK', 'LATEST_LINK'], dir)

    if flag
      nil
    else
      name
    end
  end

  def sort(ports)
    tsort = TSort.new

    ports.each do |p|
      portinfo = port(p)

      portinfo or next

      o = portinfo.origin

      deps = all_depends_list(o)	# XXX

      tsort.add(o, *deps)
    end

    tsort.tsort! & ports
  end

  def sort!(ports)
    ports.replace(sort(ports))
  end

  def recurse(portinfo, recurse_down = false, recurse_up = false)
    if not portinfo.is_a?(PortInfo)
      portinfo = port(portinfo)
    end

    list = []

    portinfo or return list

    if recurse_up
      portinfo.all_depends.map do |name|
	i = port(name)

	list << i if i
      end
    end

    list << portinfo

    if recurse_down
      # slow!
      pkgname = portinfo.pkgname.fullname

      glob do |i|
	list << i if i.all_depends.include?(pkgname)
      end
    end

    list
  end
end
