#
# Copyright (c) 2001-2004 Akinori MUSHA <knu@iDaemons.org>
# Copyright (c) 2006,2007 Sergey Matveychuk <sem@FreeBSD.org>
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
# $Id$

class PkgVersion
  include Comparable

  attr_accessor :version, :revision, :epoch

  def initialize(pkgversion)
    if /[\s-]/ =~ pkgversion    
      raise ArgumentError, "#{pkgversion}: Must not contain a '-' or whitespace."
    end

    if /^([^_,]+)(?:_(\d+))?(?:,(\d+))?$/ !~ pkgversion
      raise ArgumentError, "#{pkgversion}: Not in due form: '<version>[_<revision>][,<epoch>]'."
    end

    @version = $1
    @revision = $2 ? $2.to_i : 0
    @epoch = $3 ? $3.to_i : 0
  end

  def to_s
    s = @version
    s += '_' + @revision.to_s if @revision.nonzero?
    s += ',' + @epoch.to_s if @epoch.nonzero?

    s
  end

  def coerce(other)
    case other
    when PkgVersion
      return other, self
    when String
      return PkgVersion.new(other), self
    else
      raise TypeError, "Coercion between #{other.class} and #{self.class} is not supported."
    end
  end

  def <=>(other)
    case other
    when PkgVersion
      # ok
    when String
      other = PkgVersion.new(other)
    else
      a, b = other.coerce(self)

      return a <=> b
    end

    (@epoch <=> other.epoch).nonzero? ||
      PkgVersion.compare_numbers(@version, other.version).nonzero? ||
      @revision <=> other.revision
  end

  def PkgVersion::compare_numbers(n1, n2)
    # For full comparing rules see file:
    #	/usr/src/usr.sbin/pkg_install/lib/version.c
    special = { 'pl' => 'pl', 'alpha' => 'a', 'beta' => 'b',
      		'pre' => 'p', 'rc' => 'r' }

    n1 ||= ''
    n2 ||= ''

    # Remove padded 0's
    n1 = n1.gsub(/(^|\D)0+(\d)/, "\\1\\2")
    n2 = n2.gsub(/(^|\D)0+(\d)/, "\\1\\2")

    # Short-cut in case of equality
    if n1 == n2
      return 0
    end

    # For versions seperated with '+': e.g. 1.0.1+2004.09.06
    # split them and compare by pairs
    if /\+/ =~ n1 || /\+/ =~ n2
      a1 = n1.split(/\+/)
      a2 = n2.split(/\+/)
      c = compare_numbers(a1.shift, a2.shift)
      if c != 0
	return c
      else
        return compare_numbers(a1.shift, a2.shift)
      end
    end

    # Add separators before specials
    for s in special.keys
      n1 = n1.gsub(/(#{s})/, ".#{special[s]}")
      n2 = n2.gsub(/(#{s})/, ".#{special[s]}")
    end

    # Add missed separators.
    n1 = n1.gsub(/([a-zA-Z]\d)([a-zA-Z])/, "\\1.\\2");
    n2 = n2.gsub(/([a-zA-Z]\d)([a-zA-Z])/, "\\1.\\2");

    # Collaps consecutive separators
    n1 = n1.gsub(/([^a-zA-Z\d])+/, "\\1");
    n2 = n2.gsub(/([^a-zA-Z\d])+/, "\\1");

    # Split into subnumbers
    a1 = n1.split(/[^a-zA-Z\d]/)
    a2 = n2.split(/[^a-zA-Z\d]/)

    s1 = nil
    s2 = nil

    # Look for first different subnumber
    begin
      break if a1.empty? && a2.empty?

      s1 = a1.shift
      s2 = a2.shift
      # Magic for missing '0's: 1.0 == 1.0.0
      s1 ||= '0'
      s2 ||= '0'
    end while s1 == s2

    # Short-cut in case of equality
    if s1 == s2
      return 0
    end

    # Split into sub-subnumbers
    a1 = s1.split(/(\D+)/)
    a2 = s2.split(/(\D+)/)

    # If a string starts with a splitter, split() returns 
    # an empty first element. Adjust it.
    if /^\D/ =~ s1
      a1.shift
    end
    if /^\D/ =~ s2
      a2.shift
    end

    # Look for first different sub-subnumber
    begin
      break if a1.empty? && a2.empty?

      x1 = a1.shift
      x2 = a2.shift
    end while x1 == x2

    x1 ||= ''
    x2 ||= ''

    # Short-cut in case of equality
    if x1 == x2
      return 0
    end
 
    # Specail case - pl. It always lose.
    if x1 == "pl"
      return -1
    elsif x2 == "pl"
	return 1
    end

    if /^\D/ =~ x1		# x1: non-number
      if x2.empty?		#		vs. x2: null (5.0a > 5.0.b)
        return 1		# -> x1 wins
      end
      if /^\D/ !~ x2		#	        vs. x2: number
	return -1		# -> x2 wins
      end
      				#               vs. x2: non-number
      return x1 <=> x2		# -> Compare in dictionary order
    end

    if /^\d/ =~ x1		# x1: number
      if /^\d/ =~ x2		#               vs. x2: number
	return x1.to_i <=> x2.to_i	# -> Compare numerically
      end
				#               vs. x2: non-number
      return 1			# -> x1 wins
    end
    				# x1: null	(4a < 40a)
    return -1			# -> x2 wins
  end
end
