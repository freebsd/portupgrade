# $Id: pkginfo.rb 52 2006-01-01 06:26:59Z koma2 $

require 'pkgdb'
require 'pkgversion'
begin
  require 'features/ruby18/file'
rescue LoadError; end

class PkgInfo
  include Comparable

  PKG_INFO_CMD = PkgDB::command(:pkg_info)
  PKG_INFO_FLAGS = {
    :prefix => 'p',
    :comment => 'c',
    :descr => 'd',
    :message => 'D',
    :plist => 'f',
    :install => 'i',
    :deinstall => 'k',
    :req => 'r',
    :required_by => 'R',
    :mtree => 'm',
    :files => 'L',
    :totalsize => 's',
    :origin => 'o',
  }

  attr_accessor :name, :version

  def initialize(pkgname)
    if !pkgname.is_a?(String)
      pkgname = pkgname.to_s
    end

    if /\s/ =~ pkgname
      raise ArgumentError, "Must not contain whitespace."
    end

    if /^(.+)-([^-]+)$/ !~ pkgname
      raise ArgumentError, "Not in due form: <name>-<version>"
    end

    @name = $1
    @version = PkgVersion.new($2)
  rescue => e
    raise e, "#{pkgname}: #{e.message}"
  end

  def to_s
    @name + '-' + @version.to_s
  end

  alias fullname to_s

  def coerce(other)
    case other
    when PkgInfo
      return other, self
    when PkgVersion
      return other, @version
    when String
      if /-/ =~ other
	return PkgInfo.new(other), self
      else
	return PkgVersion.new(other), @version
      end
    else
      raise TypeError, "Coercion between #{other.class} and #{self.class} is not supported."
    end
  end

  def <=>(other)
    other_name = nil

    case other
    when PkgInfo
      other_name = other.name
      other_version = other.version
    when PkgVersion
      other_version = other
    when String
      if /-/ =~ other
	other = PkgInfo.new(other)
	other_name = other.name
	other_version = other.version
      else
	other_version = PkgVersion.new(other)
      end
    else
      a, b = other.coerce(self)

      return a <=> b
    end

    if other_name
      cmp = @name <=> other_name
      return cmp if cmp != 0
    end

    @version <=> other_version
  end

  def self.get_info(pkg, what)
    opt = PKG_INFO_FLAGS[what]

    if opt == nil
      raise ArgumentError, "#{what.to_s}: Unsupported information."
    end

    chdir = ''

    if pkg.include?('/')
      chdir = "cd #{File.dirname(pkg)};"
    end

    info = `#{chdir}env PKG_PATH= #{PKG_INFO_CMD} -q#{opt} #{pkg} 2>/dev/null`.chomp

    info.empty? ? nil : info
  end

  def get_info(what)
    PkgInfo::get_info(fullname(), what)
  end

  PKG_INFO_FLAGS.each_key do |key|
    case key
    when :files, :required_by, :origin
      next
    end

    module_eval %`
    def #{key.to_s}
      get_info(#{key.inspect})
    end
    `
  end

  def pkgdir()
    PkgDB.instance.pkgdir fullname()
  end

  def pkgfile(filename)
    PkgDB.instance.pkgfile fullname(), filename
  end

  def date_installed()
    PkgDB.instance.date_installed fullname()
  end

  def installed?()
    PkgDB.instance.installed? fullname()
  end

  def required?()
    PkgDB.instance.required? fullname()
  end

  def required_by()
    PkgDB.instance.required_by fullname()
  end

  def pkgdep()
    PkgDB.instance.pkgdep fullname()
  end

  def files()
    str = get_info(:files) || ''
    str.gsub!(%r"//+", '/')	# tr is not multibyte-aware
    str.split("\n")
  end

  def origin!()
    get_info(:origin)
  end

  def origin()
    PkgDB.instance.origin(fullname()) || origin!()
  end

  PkgDB::PKGDB_FILES.each_key do |key|
    module_eval %{
      def pkg_#{key.to_s}()
	pkgfile #{key.inspect}
      end
    }
  end

  def date_cmp(str)
    base = PkgDB.instance.date_installed(str) || PkgDB.parse_date(str)

    date_installed <=> base
  end

  def match?(pattern)
    case pattern
    when true, '*'
      true
    when Regexp
      pattern =~ fullname ? true : false
    else
      if /^([<>])(=?)(.*)/ =~ pattern
	cmp = date_cmp($3)

	($1 == '>' && cmp > 0) || ($1 == '<' && cmp < 0) || ($2 == '=' && cmp == 0)
      else
	File.fnmatch?(pattern, fullname) || @name == pattern
      end
    end
  rescue => e
    STDERR.puts e.message
    return false
  end
end

class PkgFileInfo < PkgInfo
  def initialize(pkgfile)
    @pkgfile = pkgfile

    info = PkgInfo::get_info(pkgfile, :plist)

    if info.nil?
      raise ArgumentError, "#{pkgfilename}: Couldn't get package info."
    end

    info.each_line do |line|
      if /^@name\s+(\S+)$/ =~ line
	return super($1)
      end
    end

    raise ArgumentError, "#{pkgfilename}: Couldn't get package name."
  end

  def get_info(what)
    PkgInfo::get_info(@pkgfile, what)
  end
end
