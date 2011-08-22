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
# $FreeBSD: projects/pkgtools/lib/pkgmisc.rb,v 1.12 2011-07-25 12:34:43 swills Exp $

begin
  require 'features/dir'	# for Dir.chdir(dir) { ... }
  require 'features/enum' # Enumerable#any?, etc.
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
    if /[*?{}\[\]<>()~&|\\$;\'\`\s]/ =~ arg
      '"' + arg.gsub(/([$\\\"\`])/, "\\\\\\1") + '"'
    else
      arg
    end
  }.join(' ')
end

class File
  def File.realpath(path)
    return File.expand_path(path)
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
      xsystem("rm -r #{tmpdir}")
    rescue
      warning_message "Could not clean up temporary directory: " + $!
    end
    }
  $tmpdir=tmpdir
end
