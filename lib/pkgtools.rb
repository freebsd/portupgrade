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
# $FreeBSD: projects/pkgtools/lib/pkgtools.rb,v 1.42 2011-08-18 07:36:49 stas Exp $

PREFIX = "/usr/local"
Version = "2.4.9.6"

module PkgTools
  DATE = '2012/07/29'
end

require "pkg"
require "ports"
require "pkgmisc"

require "set"
require "time"
require "delegate"
require "tempfile"

autoload "Readline", "readline"

module PkgConfig
end

def load_config
  file = ENV['PKGTOOLS_CONF'] || File.join(PREFIX, 'etc/pkgtools.conf')

  File.exist?(file) or return false

  begin
    load file
  rescue Exception => e
    STDERR.puts "** Error occured reading #{file}:",
      e.message.gsub(/^/, "\t")
    exit 1
  end

  init_pkgtools_global

  val = config_value(:SANITY_CHECK)
  val.nil? or $sanity_check = val

  if a = config_value(:PKG_SITES)
    $pkg_sites.concat(a)
  else
    $pkg_sites << PkgConfig.pkg_site_mirror()
  end

  true
end

def setproctitle(fmt, *args)
  $0 = sprintf('%s: ' << fmt, MYNAME, *args)
end

def config_value(name)
  PkgConfig.const_defined?(name) ? PkgConfig.const_get(name) : nil
end

def compile_config_table(hash)
  otable = {}
  gtable = {}

  hash.each do |pattern, value|
    $portsdb.glob(pattern) do |portinfo|
      (otable[portinfo.origin] ||= Set.new) << value
    end

    if !pattern.include?('/')
      gtable[pattern] = value
    end
  end if hash

  table = [otable, gtable]
end

def lookup_config_table(table, origin, pkgname = nil)
  otable, gtable = *table

  valueset = otable[origin] || Set.new

  if pkgname
    gtable.each do |pattern, value|
      $pkgdb.glob(pattern, false) do |name|
        if pkgname == name
          valueset << value
          break
        end
      end
    end
  end

  return nil if valueset.empty?

  valueset
end

def config_make_args(origin, pkgname = nil)
  $make_args_table ||= compile_config_table(config_value(:MAKE_ARGS))

  argset = lookup_config_table($make_args_table, origin, pkgname) or
    return nil

  argset.map { |args|
    if args.is_a?(Proc)
      String.new(args.call(origin)) rescue nil
    else
      args
    end
  }.join(' ')
end

def config_make_env(origin, pkgname = nil)
  $make_env_table ||= compile_config_table(config_value(:MAKE_ENV))

  envset = (lookup_config_table($make_env_table, origin, pkgname) or Array.new)

  make_env = Array.new

  envset.each do |envs|
    if envs.is_a?(Proc)
      make_env << String.new(envs.call(origin)) rescue nil
    elsif envs.is_a?(Array)
      envs.each do |entry|
	make_env << entry
      end
    else
      make_env << envs
    end
  end
  make_env
end

def config_commandtable(key, origin)
  $command_tables[key] ||= compile_config_table(config_value(key))

  cmdset = lookup_config_table($command_tables[key], origin) or
    return nil

  cmdset.map { |command|
    if command.is_a?(Proc)
      String.new(command.call(origin)) rescue nil
    else
      command
    end
  }.compact
end

def config_beforebuild(origin)
  config_commandtable(:BEFOREBUILD, origin)
end

def config_beforedeinstall(origin)
  config_commandtable(:BEFOREDEINSTALL, origin)
end

def config_afterinstall(origin)
  config_commandtable(:AFTERINSTALL, origin)
end

def config_use_packages_only?(p)
  config_include?(:USE_PKGS_ONLY, p)
end

def config_use_packages?(p)
  config_include?(:USE_PKGS, p)
end

def config_use_ports_only?(p)
  config_include?(:USE_PORTS_ONLY, p)
end

def config_held?(p)
  config_include?(:HOLD_PKGS, p)
end

def config_ignore_moved?(p)
  config_include?(:IGNORE_MOVED, p)
end

def config_include?(key, p)
  if $config_include_table.key?(key)
    set = $config_include_table[key]
  else
    set = $config_include_table[key] = Set.new

    if a = config_value(key)
      a.each do |pattern|
	$portsdb.glob(pattern) do |portinfo|
	  set << portinfo.origin
	end

	if pkgnames = $pkgdb.deorigin_glob(pattern)
	  pkgnames.each do |pkgname|
	    set << pkgname
	  end
	end

	set.merge($pkgdb.glob(pattern, false))
      end
    end
  end

  case p
  when PortInfo
    set.include?(p.origin)
  when PkgInfo
    (o = p.origin and set.include?(o)) ||
      set.include?(p.fullname)
  else
    set.include?(p)
  end
end

def init_pkgtools_global
  # initialize pkgdb first - PortsDB uses PkgDB.instance.db_dir.
  $pkgdb = PkgDB.instance.setup
  $pkgdb_dir = $pkgdb.db_dir
  $portsdb = PortsDB.instance.setup
  $ports_dir = $portsdb.ports_dir
  $packages_base = ENV['PACKAGES'] || File.join($ports_dir, 'packages')
  $packages_dir = File.join($packages_base, 'All')
  init_tmpdir
  $pkg_path = ENV['PKG_PATH'] || $packages_dir

  $pkg_sites = (ENV['PKG_SITES'] || '').split

  $verbose = false
  $sudo_args = ['sudo']
  $sudo = false

  $timer = {}

  $make_args_table = nil
  $command_tables = {}

  $config_include_table = {}

  $portsdb.ignore_categories = config_value(:IGNORE_CATEGORIES) || []
  $portsdb.extra_categories = config_value(:EXTRA_CATEGORIES) || []
  alt_moved = config_value(:ALT_MOVED) || []
  unless alt_moved.empty?
    alt_moved.each do |f|
      $portsdb.moved.fill(f)
    end
  end
end

def parse_pattern(str, regex = false)
  if str[0] == ?:
    regex = true
    str = str[1..-1]
  end

  if regex
    Regexp.new(str)
  else
    str
  end
end

def stty_sane
  system '/bin/stty', 'sane' if STDIN.tty?
end

def progress_message(message, io = STDOUT)
  io.puts "--->  " + message
end

def information_message(message, io = STDERR)
  io.puts "++ " + message
end

def warning_message(message, io = STDERR)
  io.puts "** " + message
end

def all?(str)
  /^a/i =~ str
end

def yes?(str)
  /^y/i =~ str
end

def no?(str)
  /^n/i =~ str
end

def yesno_str(yes)
  if yes then 'yes' else 'no' end
end
  
def prompt_yesno(message = "OK?", yes_by_default = false)
  if $automatic
    input = yesno_str(yes_by_default)

    if $verbose
      print "#{message} [#{yesno_str(yes_by_default)}] "
      puts input
    end
  else
    print "#{message} [#{yesno_str(yes_by_default)}] "

    STDOUT.flush
    input = (STDIN.gets || '').strip
  end

  if yes_by_default
    !no?(input)
  else
    yes?(input)
  end
end

def prompt_yesnoall(message = "OK?", yes_by_default = false)
  print "#{message} ([y]es/[n]o/[a]ll) [#{yesno_str(yes_by_default)}] "

  if $automatic
    input = yesno_str(yes_by_default)
    puts input if $verbose
  else
    STDOUT.flush
    input = (STDIN.gets || '').strip
  end

  if all?(input)
    :all
  elsif yes_by_default
    !no?(input)
  else
    yes?(input)
  end
end

def matchlen(a, b)
  i = 0
  0.upto(a.size) { |i| a[i] != b[i] and break }
  i
end

def input_line(prompt, add_history = nil, completion_proc = nil)
  prev_proc = Readline.completion_proc

  Readline.completion_append_character = nil if Readline.respond_to?(:completion_append_character=)
  Readline.completion_proc = completion_proc if completion_proc.respond_to?(:call)

  Readline.readline(prompt, add_history)
ensure
  Readline.completion_proc = prev_proc if prev_proc.respond_to?(:call)
end

def input_file(prompt, dir, add_history = nil)
  Dir.chdir(dir) {
    return input_line(prompt, add_history, Readline::FILENAME_COMPLETION_PROC)
  }
end

OPTIONS_NONE	= 0x00
OPTIONS_SKIP	= 0x01
OPTIONS_DELETE	= 0x02
OPTIONS_ALL	= 0x04
OPTIONS_HISTORY	= 0x08

def choose_from_options(message = 'Input?', options = nil, flags = OPTIONS_NONE)
  skip		= (flags & OPTIONS_SKIP).nonzero?
  delete	= (flags & OPTIONS_DELETE).nonzero?
  all		= (flags & OPTIONS_ALL).nonzero?
  history	= (flags & OPTIONS_HISTORY).nonzero?

  completion_proc = nil

  unless options.nil?
    case options.size
    when 0
      return :skip
    else
      completion_proc = proc { |head|
	len = head.size
	options.select { |option| head == option[0, len] }
      }
    end
  end

  loop do
    input = input_line(message + ' (? to help): ', history, completion_proc)

    if input.nil?
      print "\n"

      next if not delete

      if all
	ans = prompt_yesnoall("Delete this?", true)
      else
	ans = prompt_yesno("Delete this?", true)
      end

      if ans == :all
	return :delete_all
      elsif ans
	return :delete
      end

      next
    end

    input.strip!

    case input
    when '.'
      return :abort
    when '?'
      print ' [Enter] to skip,' if skip
      print ' [Ctrl]+[D] to delete,' if delete
      print '  [.][Enter] to abort, [Tab] to complete'
      print "\n"
      next
    when ''
      if skip
	if all
	  ans = prompt_yesnoall("Skip this?", true)
	else
	  ans = prompt_yesno("Skip this?", true)
	end

	if ans == :all
	  return :skip_all
	elsif ans
	  return :skip
	end
      end

      next
    else
      if options.include?(input)
	return input
      end

      print "Please choose one of these:\n"

      if options.size <= 20
	puts options.join('  ')
      else
	puts options[0, 20].join('  ') + "  ..."
      end
    end
  end

  # not reached
end

class CommandFailedError < StandardError
end

# xsystem
def __system(x, *args)
  system(*args) and return true

  if x
    raise CommandFailedError, format('Command failed [exit code %d]: %s', $? >> 8, shelljoin(*args))
  end

  false
end
def xsystem(*args)
  __system(true, *args)
end

# sudo, xsudo
def __sudo(x, *args)
  if $sudo && Process.euid != 0
    if $sudo_args.grep(/%s/).empty?
      args = $sudo_args + args
    else
      args = $sudo_args.map { |arg|
	format(arg, shelljoin(*args)) rescue arg
      }
    end

    progress_message "[Executing a command as root: " + shelljoin(*args) + "]"
  end

  __system(x, *args)
end
def sudo(*args)
  __sudo(false, *args)
end
def xsudo(*args)
  __sudo(true, *args)
end

# system!, xsystem!
alias system! sudo
alias xsystem! xsudo

def logged_command(file, args)
  if !file  
    args
  else
    ['/usr/bin/script', '-qa', file, *args]
  end
end

# script, xscript
def __script(x, file, *args)
  __system(x, *logged_command(file, args))
end
def script(file, *args)
  __script(false, file, *args)
end
def xscript(file, *args)
  __script(true, file, *args)
end

# script!, xscript!
def __script!(x, file, *args)
  __sudo(x, *logged_command(file, args))
end
def script!(file, *args)
  __script!(false, file, *args)
end
def xscript!(file, *args)
  __script!(true, file, *args)
end

# raises CommandFailedError
def install_data(src, dst, backup = false)
  cmd = ['/usr/bin/install']
  cmd.push('-b') if backup
  cmd.push('-m', '644', src, dst)

  begin
    xsystem(*cmd)
  rescue CommandFailedError => e
    if $sudo && Process.euid != 0
      information_message "Retrying install as root"
      xsystem!(*cmd)
    else
      raise e
    end
  end
end

# raises CommandFailedError and Errno::*
def unlink_file(file)
  File.exist?(file) or return

  begin
    File.unlink(file)
  rescue => e
    if $sudo && Process.euid != 0
      xsystem!('/bin/rm', '-f', file)
    else
      raise e
    end
  end
end

# backquote
def __backquote(x, sudo, *args)
  if sudo && Process.euid != 0
    if $sudo_args.grep(/%s/).empty?
      args = $sudo_args + args
    else
      args = $sudo_args.map { |arg|
	format(arg, shelljoin(*args)) rescue arg
      }
    end

    cmdline = shelljoin(*args)

    progress_message "[Executing a command as root: " + cmdline + "]"
  else
    cmdline = shelljoin(*args)
  end

  str = `#{cmdline}` and return str

  if x
    raise CommandFailedError, format('Command failed [exit code %d]: %s', $? >> 8, cmdline)
  end

  false
end
def backquote(*args)
  __backquote(false, false, *args)
end
def xbackquote(*args)
  __backquote(true, false, *args)
end
def backquote!(*args)
  __backquote(false, $sudo, *args)
end
def xbackquote!(*args)
  __backquote(true, $sudo, *args)
end

def grep_q_file(re, file)
  case re
  when Regexp
    pat = re.source
  else
    pat = re.to_s
  end

  system '/usr/bin/egrep', '-q', pat, file
end

def alt_dep(dep, origin = nil)
  hash = config_value(:ALT_PKGDEP) or return nil

  if dep == ''
    dep = $pkgdb.deorigin(origin).to_s
  end

  hash.each do |pat, alt|
    begin
      pat = parse_pattern(pat)
    rescue RegexpError => e
      warning_message e.message.capitalize
      next
    end

    # pattern allowed both in origin and pkgname
    if pat.index('/')
      next if !origin || !File.fnmatch?(pat, origin)
    elsif !File.fnmatch?(pat, dep)
      next
    end

    case alt
    when :delete, :skip
      return [alt]
    else
      begin
	alt = parse_pattern(alt)
      rescue RegexpError => e
	warning_message e.message.capitalize
	next
      end

      pkgnames = $pkgdb.glob(alt, false)

      if pkgnames.empty?
	return nil
      else
	return pkgnames
      end
    end
  end

  nil
end

# raises StandardError
def modify_pkgdep(pkgname, dep, newdep, neworigin = nil)
  pkgdir = $pkgdb.pkgdir(pkgname)
  return if pkgdir.nil? || !File.directory?(pkgdir)
  changed = false

  pkgver_re = %r{-\d\S*$}
  file = $pkgdb.pkg_contents(pkgname)

  if ! newdep == :add
    grep_q_file(/^@pkgdep[[:space:]]+#{Regexp.quote(dep)}$/, file) or return
  end

  case newdep
  when :delete
    neworigin = nil
  else
    neworigin ||= $pkgdb.origin(newdep)
  end

  content = File.open(file)

  pkgdeps = Set.new

  deporigin = nil	# what to do with the next DEPORIGIN

  head_lines = []
  depends_lines = []
  tail_lines = []

  pkgdep_undeleted = false
  deporigin_undeleted = false
  last_correct = false

  content.each do |line|
    case line
    when /^@pkgdep\s+(\S+)/
      deporigin = :keep

      pkgdep = $1

      if pkgdeps.include?(pkgdep)	# remove duplicates
	deporigin = :delete
	changed = true
	next
      end

      pkgdeps << pkgdep

      if $1 == dep
	if newdep == :delete
	  depends_lines << "@comment DELETED:pkgdep #{pkgdep}\n"
	  deporigin = :commentout
	else
	  depends_lines << "@pkgdep #{newdep}\n"

	  if neworigin
	    depends_lines << "@comment DEPORIGIN:#{neworigin}\n"
	  end

	  deporigin = :delete

	  pkgdeps << newdep
	end
	changed = true
      else
	depends_lines << line
      end
    when /^@comment\s+DEPORIGIN:(\S+)/
      case deporigin
      when :commentout
	depends_lines << "@comment DELETED:DEPORIGIN:#{$1}\n"
	changed = true
      when :keep
	depends_lines << line
      else # :delete, nil
	# no output
	changed = true
      end

      deporigin = nil
    when /^@comment\s+DELETED:(pkgdep |DEPORIGIN:)(\S+)/
      # Undelete it if requested
      if newdep == :add
	keyword = $1
	data = $2
	if keyword == "pkgdep " && 
	  		data.sub(pkgver_re,'') == dep.sub(pkgver_re,'')
	  depends_lines << "@pkgdep #{dep}\n"
	  pkgdep_undeleted = true
	  last_correct = true
	  changed = true
	  next
	elsif keyword == "DEPORIGIN:" && data == neworigin
	  # Undelete DEPORIGIN only if we sure the last line is correct
	  if last_correct
	    depends_lines << "@comment DEPORIGIN:#{neworigin}\n"
	    deporigin_undeleted = true
	    changed = true
	    next
	  end
	end
	depends_lines << line
      else
	depends_lines << line
      end
    else
      if depends_lines.empty?
	head_lines << line
      else
	tail_lines << line
      end

      deporigin = nil
      last_correct = false
    end
  end
  content.close

  if newdep == :add && (!pkgdep_undeleted || !deporigin_undeleted)
    # Remove partly undeleted entry
    if pkgdep_undeleted
      depends_lines.delete_if { |line| line == "@pkgdep #{dep}\n" }
    end
    # and just add correct lines
    depends_lines << "@pkgdep #{dep}\n"
    depends_lines << "@comment DEPORIGIN:#{neworigin}\n"
    changed = true
  end

  if changed
    lines = head_lines + depends_lines + tail_lines
    w = Tempfile.new(File.basename(file))
    w.print(*lines)
    w.close
    tmpfile = w.path

    progress_message "Modifying #{file}" if $verbose

    install_data(tmpfile, file)
  end
rescue => e
  raise "Failed to rewrite #{file}: " + e.message
end

# raises CommandFailedError
def update_pkgdep(oldpkgname, newpkgname, neworigin = nil)
  return if oldpkgname == newpkgname

  progress_message "Updating dependency info" if $verbose

  $pkgdb.installed_pkgs.each do |pkgname|
    modify_pkgdep(pkgname, oldpkgname, newpkgname, neworigin)
  end
end

def modify_origin(pkgname, origin)
  contents_file = $pkgdb.pkg_contents(pkgname)

  if grep_q_file(/^@comment[ \t]+ORIGIN:/, contents_file)
    command = shelljoin('sed',
			"s|^\\(@comment[ \t][ \t]*ORIGIN:\\).*$|\\1#{origin}|")
  else
    command = "(cat; echo '@comment ORIGIN:#{origin}')"
  end

  filter_file(command, contents_file)

  $pkgdb.set_origin(pkgname, origin)
rescue => e
  raise "Failed to rewrite #{contents_file}: " + e.message
end

def identify_pkg(path)
  dir, file = File.split(path)

  pkgname = nil
  origin = nil
  pkgdep = []

  IO.popen("cd #{dir} && #{PkgDB::command(:pkg_info)} -qfo #{file}") do |r|
    r.each do |line|
      case line
      when /^@name\s+(\S*)/
	pkgname = $1
      when /^@pkgdep\s+(\S*)/
	pkgdep << $1
      when /^(\S+\/\S+)$/		# /
	origin = $1
      end
    end
  end

  return pkgname, origin, pkgdep
rescue => e
  warning_message e.message
  return nil
end

# raises CommandFailedError
def filter_file(command, file, backup = false)
  w = Tempfile.new(File.basename(file))
  w.close
  tmpfile = w.path

  xsystem("#{command} < #{file} > #{tmpfile}")

  progress_message "Filtering #{file}" if $verbose

  install_data(tmpfile, file, backup)
end

def search_paths(command)
  ENV['PATH'].split(':').each do |dir|
    path = File.join(dir, command)
    stat = File.stat(path)
    return path if stat.file? && stat.executable?(path)
  end

  nil
end

def timer_start(name, verbose = $verbose)
  $timer[name] = start_time = Time.now

  if verbose
    progress_message "#{name} started at: #{start_time.rfc2822}"
  end
end

def timer_end(name, verbose = $verbose)
  return if $timer.nil?
  $timer.key?(name) or return

  end_time = Time.now

  start_time = $timer[name]

  time = end_time - start_time
  days = time/86400
  str_time = ""
  if days.to_i > 0
    str_time = "#{days.to_i} day"
    str_time += "s" if days.to_i > 1
    str_time += " and "
  end
  str_time += Time.at(time).utc.strftime("%T")

  if verbose
    progress_message "#{name} ended at: #{end_time.rfc2822} (consumed #{str_time})"
  end

  $timer.delete(name)
end

class PkgResult
  attr_accessor :item, :result, :info

  def initialize(item, result, info = nil)
    if item.nil? then
      raise ArgumentError
    end
    @item = item
    @result = result
    @info = info
  end

  def done?
    @result == :done
  end
  
  def ignored?
    @result == :ignored
  end

  def skipped?
    @result == :skipped
  end

  def error?
    !@result.is_a?(Symbol)
  end

  def ok?
    done?
  end

  def failed?
    !ok?
  end

  def self.phrase(result, long = false)
    case result
    when :done
      "done"
    when :ignored
      long ? "been ignored" : "ignored"
    when :skipped
      long ? "been skipped" : "skipped"
    else
      "failed"
    end
  end

  def phrase(long = false)
    PkgResult.phrase(@result, long)
  end

  def self.sign(result, long = false)
    case result
    when :done
      sign = "+"
    when :ignored
      sign = "-"
    when :skipped
      sign = "*"
    else
      sign = "!"
    end

    if long
      sign << ":" << phrase(result)
    else
      sign
    end
  end

  def sign(long = false)
    PkgResult.sign(@result, long)
  end

  def message
    case @result
    when Symbol
      nil
    when Exception
      @result.message
    else
      @result
    end
  end

  def write(io = STDOUT, prefix = "\t")
    if @info
      str = "#{@item} (#{@info})"
    else
      str = @item
    end

    line = prefix.dup << sign << " " << str

    if str = message()
      line << "\t(" << str << ")"
    end

    io.puts line
  end
  
  def self.legend(long = false)
    if long
      [:done, :ignored, :skipped, :error]
    else
      [:ignored, :skipped, :error]
    end.map { |r| sign(r, true) }.join(" / ")
  end
end

class PkgResultSet < SimpleDelegator
  def initialize
    @array = []
    super(@array)
  end

  def [](item)
    @array.find { |r| r.item == item }
  end

  def progress_message(message, io = STDOUT)
    io.puts "--->  " + message
  end

  def warning_message(message, io = STDERR)
    io.puts "** " + message
  end

  def include?(item)
    @array.any? { |r| r.item == item }
  end

  def summary
    count = Hash.new(0)
    
    each do |result|
      if result.done?
        count[:done] += 1
      elsif result.error?
        count[:error] += 1
      elsif result.ignored?
        count[:ignored] += 1
      elsif result.skipped?
        count[:skipped] += 1
      end
    end

    [:done, :ignored, :skipped, :error].map { |e|
      "#{count[e]} #{PkgResult.phrase(e)}"
    }.join(', ').sub(/, ([^,]+)$/, " and \\1")
  end

  def write(io = STDOUT, prefix = "\t", verbose = $verbose)
    errors = 0

    each do |result|
      next if !verbose && result.ok?

      errors += 1 if result.error?

      result.write(io, prefix)
    end

    errors
  end

  def show(done_service = 'done', verbose = $verbose)
    if verbose
      if empty?
	warning_message "None has been #{done_service}."
	return 0
      end

      progress_message "Listing the results (" <<
	PkgResult.legend(true) << ")"
    else
      if find { |r| r.ignored? || r.failed? }
	warning_message "Listing the failed packages (" <<
	  PkgResult.legend() << ")"
      end
    end

    errors = write(STDOUT, "\t", verbose)

    progress_message "Packages processed: " << summary() if verbose

    errors
  end
end

def set_signal_handlers
  for sig in [:SIGINT, :SIGQUIT, :SIGTERM]
    trap(sig) do
      puts "\nInterrupted."
      $interrupt_proc.call if $interrupt_proc
      stty_sane
      exit
    end
  end

#  trap(:SIGCHLD) do
#    begin
#      true while Process.waitpid(-1, Process::WNOHANG)
#    rescue Errno::ECHILD
#    end
#  end
end

module PkgConfig
  uname = `uname -rm`.chomp

  if m = /^(((\d+)(?:\.\d+[^.\-]*?)+)-(\w+)(-\S+)?) (\w+)$/.match(uname)
    OS_RELEASE, OS_REVISION, OS_MAJOR,
      OS_BRANCH, os_patchlevel, OS_PLATFORM = m[1..-1]
    OS_PATCHLEVEL = os_patchlevel || ""

    case OS_BRANCH
    when /^CURRENT$/	# <n>-current
      OS_PKGBRANCH = sprintf('%s-%s', OS_MAJOR, OS_BRANCH.downcase)
    when /^RELEASE$/	# <n>.<m>-release
      OS_PKGBRANCH = sprintf('%s-%s', OS_REVISION, OS_BRANCH.downcase)
    else		# <n>-stable
      # when /^(PRERELEASE|RC\d*|ALPHA|BETA)$/
      OS_PKGBRANCH = sprintf('%s-%s', OS_MAJOR, 'stable')
    end
  else
    STDERR.puts "uname(1) could be broken - cannot parse the output: #{uname}"
  end

  def pkg_site_mirror(root = ENV['PACKAGEROOT'] || 'ftp://ftp.FreeBSD.org/')
    sprintf('%s/pub/FreeBSD/ports/%s/packages-%s/',
	    root, OS_PLATFORM, OS_PKGBRANCH)
  end

  def pkg_site_primary()
    pkg_site_mirror('ftp://ftp.FreeBSD.org')
  end

  def pkg_site_builder(latest = false)
    run = latest ? 'latest' : 'full'

    case OS_PLATFORM
    when 'i386', 'sparc64', 'amd64', 'ia64'
      sprintf('http://pointyhat.FreeBSD.org/errorlogs/%s-%s-packages-%s/',
	      OS_PLATFORM, OS_MAJOR, run)
    else
      raise sprintf('There is no official package builder site yet for the %s platform.',
		    OS_PLATFORM)
    end
  end

  module_function :pkg_site_mirror, :pkg_site_primary, :pkg_site_builder

  def localbase()
    $portsdb.localbase
  end

  def x11base()
    $portsdb.x11base
  end

  module_function :localbase, :x11base

  def deorigin(origin)
    if ret = $pkgdb.deorigin(origin)
      ret.first
    else
      raise "No package is found to be installed from '#{origin}'!"
    end
  end

  def enabled_rc_scripts(origin_or_pkgname)
    if origin_or_pkgname.include?('/')
      pkgname = deorigin(origin_or_pkgname)
    else
      pkgname = origin_or_pkgname
    end

    pkg = PkgInfo.new(pkgname)

    re = %r"^((?:#{Regexp.quote(localbase())}|#{Regexp.quote(x11base())})/etc/rc\.d/[^/]+(\.sh)?)(\.\w+)?$"

    ret = []
    pkg.files.each { |file|
      ret << $1 if re =~ file && File.executable?($1)
    }
    ret
  end

  def disabled_rc_scripts(origin_or_pkgname)
    if origin_or_pkgname.include?('/')
      pkgname = deorigin(origin_or_pkgname)
    else
      pkgname = origin_or_pkgname
    end

    pkg = PkgInfo.new(pkgname)

    re = %r"^((?:#{Regexp.quote(localbase())}|#{Regexp.quote(x11base())})/etc/rc\.d/[^/]+(\.sh)?)(\.\w+)$"

    pkg.files.select { |file|
      re =~ file && File.executable?(file)
    }
  end

  def cmd_start_rc(origin)
    enabled_rc_scripts(origin).map { |file| "#{file} start" }.join("; ")
  end

  def cmd_stop_rc(origin)
    enabled_rc_scripts(origin).map { |file| "#{file} stop" }.join("; ")
  end

  def cmd_restart_rc(origin)
    enabled_rc_scripts(origin).map { |file| "#{file} stop; sleep 3; #{file} start" }.join("; ")
  end

  def cmd_disable_rc(origin)
    enabled_rc_scripts(origin).map { |file| "mv -f #{file} #{file}.disable" }.join("; ")
  end

  def cmd_enable_rc(origin)
    disabled_rc_scripts(origin).map { |file| "cp -p #{file} #{file.sub(/\.\w+$/, '')}" }.join("; ")
  end

  def include_eval(file)
    file = File.join(PREFIX, file)

    File.exist?(file) or return false

    begin
      load file
    rescue Exception => e
      STDERR.puts "** Error occured reading #{file}:",
	e.message.gsub(/^/, "\t")
      exit 1
    end
  end

  def include_hash(glob)
    hash = Hash.new
    Dir.glob(File.join(PREFIX, glob)) do |f|
      if FileTest.file?(f)
	File.open(f) do |file|
	  file.each_line do |line|
	    next if /^#/ =~ line
	    if /=>/ =~ line
	      key, val = line.split('=>')
	      key.strip!.gsub!(/['"]/, '')
	      val.strip!.gsub!(/['",]/, '')
	      hash[key] = val
	    else
	      unless line.empty?
		raise "File #{f}: syntax error in line: #{line}"
	      end
	    end
	  end
	end
      end
    end

    hash
  end

  module_function :deorigin,
    :enabled_rc_scripts,  :disabled_rc_scripts,
    :cmd_start_rc, :cmd_stop_rc, :cmd_restart_rc,
    :cmd_disable_rc, :cmd_enable_rc,
    :include_eval, :include_hash
end
