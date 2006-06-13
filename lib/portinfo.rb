# $Id: portinfo.rb 52 2006-01-01 06:26:59Z koma2 $

require 'portsdb'
require 'pkginfo'

class PortInfo
  include Comparable

  FIELDS = [ :pkgname, :origin, :prefix, :comment, :descr_file,
             :maintainer, :categories, :build_depends, :run_depends, :www ]
  LIST_FIELDS = [ :categories, :build_depends, :run_depends ]
  PORTS_DIR_FIELDS = [ :origin, :descr_file ]
  NFIELDS = FIELDS.size
  FIELD_SEPARATOR = '|'

  def initialize(line)
    line.is_a?(String) or raise ArgumentError,
      "You must specify a one line text of port info."

    values = line.chomp.split(FIELD_SEPARATOR, -1)

    if values.size < NFIELDS || values[NFIELDS - 1].index(FIELD_SEPARATOR)
      raise ArgumentError, "Port info line must consist of #{NFIELDS} fields."
    end

    @attr = {}

    ports_dir = nil

    FIELDS.each_with_index do |field, i|
      value = values[i]

      case field
      when :pkgname
	begin
	  value = PkgInfo.new(value)
	rescue => e
	  raise ArgumentError, e.message
	end
      when :origin
	if value.sub!(%r`^(.*)/([^/]+/[^/]+)$`, '\\2')
	  ports_dir = $1
	else
	  raise ArgumentError, "#{@attr[:pkgname]}: #{value}: malformed origin"
	end
      when :descr_file
	value.sub!(%r`^#{Regexp.quote(ports_dir)}/`, '')
      when *LIST_FIELDS
	value = value.split
      else
	if value.empty?
	  value = nil
	end
      end

      @attr[field] = value
    end
  end
  
  FIELDS.each do |field|
    module_eval %`
    def #{field.to_s}
      @attr[#{field.inspect}]
    end
    `
  end

  def to_s(ports_dir = PortsDB.instance.ports_dir)
    FIELDS.collect { |field|
      value = @attr[field]

      if value.nil?
	''
      else
	case field
	when :pkgname
	  value = value.to_s
	when :origin, :descr_file
	  value = File.join(ports_dir, value)
	when *LIST_FIELDS
	  value.join ' '
	else
	  value
	end
      end
    }.join(FIELD_SEPARATOR) + "\n"
  end

  def <=>(other)
    other_name = nil

    case other
    when PortInfo
      return origin <=> other.origin
    when PkgInfo
      return origin <=> other.origin
    when String
      return origin <=> other
    else
      a, b = other.coerce(self)

      return a <=> b
    end
  end

  def category()
    categories().first
  end

  def all_depends()
    build_depends | run_depends
  end

  def self.match?(pattern, origin)
    if pattern.is_a?(String)
      File.fnmatch?(pattern, origin, File::FNM_PATHNAME)
    else
      pattern === origin ? true : false
    end
  end

  def match?(pattern)
    PortInfo.match?(pattern, @attr[:origin]) ||
      @attr[:pkgname].match?(pattern)
  end

  def portdir()
    PortsDB.instance.portdir origin()
  end

  def exist?()
    PortsDB.instance.exist? origin()
  end

  def masters()
    PortsDB.instance.masters origin()
  end
end
