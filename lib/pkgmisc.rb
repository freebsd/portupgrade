# $Id: pkgmisc.rb 52 2006-01-01 06:26:59Z koma2 $

begin
  require 'features/ruby18/dir'	# for Dir.chdir(dir) { ... }
  require 'features/ruby18/enum' # Enumerable#any?, etc.
rescue LoadError
end

class Array
  def qindex(item)
    lower = -1
    upper = size()
    while lower + 1 != upper
      mid = (lower + upper) / 2

      cmp = self[mid] <=> item

      cmp.zero? and return mid

      if cmp < 0
	lower = mid
      else
	upper = mid
      end
    end

    nil
  end

  alias qinclude? qindex
end

def shellwords(line)
  unless line.kind_of?(String)
    raise ArgumentError, "Argument must be String class object."
  end
  line = line.sub(/\A\s+/, '')
  words = []
  while line != ''
    field = ''
    while true
      if line.sub!(/\A"(([^"\\]|\\.)*)"/, '') then #"
	snippet = $1
	snippet.gsub!(/\\(.)/, '\1')
      elsif line =~ /\A"/ then #"
	raise ArgumentError, "Unmatched double quote: #{line}"
      elsif line.sub!(/\A'([^']*)'/, '') then #'
	snippet = $1
      elsif line =~ /\A'/ then #'
	raise ArgumentError, "Unmatched single quote: #{line}"
      elsif line.sub!(/\A\\(.)/, '') then
	snippet = $1
      elsif line.sub!(/\A([^\s\\'"]+)/, '') then #'
	snippet = $1
      else
	line.sub!(/\A\s+/, '')
	break
      end
      field.concat(snippet)
    end
    words.push(field)
  end
  words
end

def shelljoin(*args)
  args.collect { |arg|
    if /[*?{}\[\]<>()~&|\\$;\'\`\"\s]/ =~ arg
      '"' + arg.gsub(/([$\\\"\`])/, "\\\\\\1") + '"'
    else
      arg
    end
  }.join(' ')
end

class File
  begin
    require 'dl/import'
  
    module LIBC
      PATH_MAX = 1024

      extend DL::Importable
      dlload "libc.so"
      extern "const char *realpath(char *, char *)"
    end
  
    def File.realpath(path)
      return LIBC.realpath(path, "\0" * LIBC::PATH_MAX) ||
	File.expand_path(path)
    end
  rescue LoadError, RuntimeError
    def File.realpath(path)
      return File.expand_path(path)
    end
  end
end

def init_tmpdir
  if ! $tmpdir.nil? && $tmpdir != "" then
    return
  end
  maintmpdir = ENV['PKG_TMPDIR'] || ENV['TMPDIR'] || '/var/tmp'
  if !FileTest.directory?(maintmpdir)
    raise "Temporary directory #{maintmpdir} does not exist"
  end

  cmdline = shelljoin("/usr/bin/mktemp", "-d", maintmpdir + "/portupgradeXXXXXXXX")
  pipe = IO.popen(cmdline)
  tmpdir = pipe.gets
  pipe.close
  if $? != 0 || tmpdir.nil? || tmpdir.length == 0
    raise "Could not create temporary directory in #{maintmpdir}"
  end
  tmpdir.chomp!

  at_exit {
    begin
      Dir.delete(tmpdir)
    rescue
      warning_message "Could not clean up temporary directory: " + $!
    end
    }
  $tmpdir=tmpdir
end
