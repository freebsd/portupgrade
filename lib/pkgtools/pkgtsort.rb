# vim: set sts=2 sw=2 ts=8 et:
#
# Copyright (c) 2001-2004 Akinori MUSHA <knu@iDaemons.org>
# Copyright (c) 2006-2008 Sergey Matveychuk <sem@FreeBSD.org>
# Copyright (c) 2009-2012 Stanislav Sedov <stas@FreeBSD.org>
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

#
# Topological Sorter
#

class TSort
  def initialize()
    @hints = Hash.new([])
  end

  def empty?()
    @hints.empty?
  end

  def clear()
    @hints.clear
  end

  def dump()
    @hints.dup
  end

  def dup()
    Marshal.load(Marshal.dump(self))
  end

  # add(a, *b) :	Tell that <a> depends on <*b>.
  def add(a, *b)
    a.nil? and return self

    b.delete(nil)
    @hints[a] |= b

    b.each do |x|
      @hints[x] = [] if not @hints.include?(x)
    end

    self
  end

  # delete(a) :		Tell that <a> no longer exists.
  # delete(a, *b) :	Tell that <a> no longer depends on <*b>.
  def delete(a, *b)
    @hints.include?(a) or return self

    if b.empty?
      @hints.delete(a)

      @hints.each_key do |x|
	@hints[x].delete(a)
      end
    else
      @hints[a] -= b
    end

    self
  end

  # tsort!(&block) :	Perform sort and return a sorted array.
  #			Everything is cleared when it is done.
  #			If no block is given, it automatically unlinks
  #			cycles.  If a block is given, it yields the
  #			block with a cycle every time it finds one,
  #			and the block can return an index to indicate
  #			where it should unlink the cycle.  If the
  #			block returns nil, it quits immediately
  #			returning nil.
  def tsort!(&block)
    result = []

    until empty?
      ary = @hints.sort { |a,b| b[1].size <=> a[1].size }
      key, deps = ary.pop

      if deps.empty?
	result << key

	delete(key)
      else
	# there must be a cycle - find it
	while (cycle = find_cycle(key)).nil?
	  if ary.empty?
	    raise 'cannot resolve cyclic dependency - maybe a bug.'
	  end

	  key, deps = ary.pop
	end

	if block
	  # yield <block> with the found cycle
	  at = block.call(cycle)

	  return nil if at.nil?

	  if cycle[at + 1].nil?
	    delete(cycle.last, cycle.first)
	  else
	    delete(cycle[at], cycle[at + 1])
	  end
	else
	  # unlink the cycle
	  delete(cycle.last, cycle.first)
	end

	return result + tsort!(&block)
      end
    end

    result
  end

  # tsort(&block) :	Same as tsort! but not destructive. (It costs)
  def tsort(&block)
    dup.tsort!(&block)
  end

  private
  def find_cycle(start, current = start, path = [])
    deps = @hints[current]

    if deps.include?(start)
      return path + [start]
    end

    deps.each do |dep|
      next if path.include?(dep)

      if cycle = find_cycle(start, dep, path + [dep])
	return cycle
      end
    end

    return nil
  end
end

if __FILE__ == $0
  t = TSort.new
  t.add(1, 2, 3).add(2, 4).add(3, 4).add(2, 3).add(1,3).add(6, 5).add(5, 1)

  p t.dump
  a = t.tsort { |cycle| puts "cycle found: " + cycle.join('-'); false }
  puts(*a)

  t = TSort.new
  t.add(1, 2, 3).add(2, 4).add(3, 4).add(2, 3).add(4,1).add(1,3).add(6, 5).add(5, 6)

  p t.dump
  a = t.tsort { |cycle| puts "cycle found: " + cycle.join('-'); nil }
  puts(*a)

  p t.dump
  a = t.tsort! { |cycle| puts "cycle found: " + cycle.join('-'); 1 }
  puts(*a)

  p t.dump
end
