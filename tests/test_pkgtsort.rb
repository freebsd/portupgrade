#!/usr/bin/env ruby
#
# $Id: test_pkgtsort.rb 1028 2004-07-20 11:14:02Z knu $
$:.push("..")

require 'test/unit'

require 'pkgtsort'

class TestTSort < Test::Unit::TestCase
  def test_s_new
    assert_raises(ArgumentError) { TSort.new(1) }
    assert_raises(ArgumentError) { TSort.new(nil) }
  end

  def test_add
    t = TSort.new

    t.add(1, 2, 3)
    d = t.dump

    assert_equal([1, 2, 3], d.keys.sort)
    assert_equal([2, 3], d[1].sort)
    assert_equal([], d[2])
    assert_equal([], d[3])

    t.add(2, 4)
    t.add(2, 3)
    d = t.dump

    assert_equal([1, 2, 3, 4], d.keys.sort)
    assert_equal([2, 3], d[1].sort)
    assert_equal([3, 4], d[2].sort)
    assert_equal([], d[3])
    assert_equal([], d[4])
  end

  def test_delete
    t = TSort.new

    t.add(1, 2, 3)
    t.add(5, 1, 3, 4)
    t.add(4, 2)

    t.delete(3)
    d = t.dump

    assert_equal([1, 2, 4, 5], d.keys.sort)
    assert_equal([2], d[1])
    assert_equal([], d[2])
    assert_equal([2], d[4])
    assert_equal([1, 4], d[5])

    t.delete(5, 4)
    d = t.dump

    assert_equal([1, 2, 4, 5], d.keys.sort)
    assert_equal([2], d[1])
    assert_equal([], d[2])
    assert_equal([2], d[4])
    assert_equal([1], d[5])
  end

  def test_tsort
    t = TSort.new

    t.add(1, 2, 3)
    t.add(2, 4)
    t.add(2, 3)
    assert_equal([4, 3, 2, 1], t.tsort)

    t.add(3, 2)

    t.tsort { |cycle|
      assert_equal([2, 3], cycle.sort)
    }
  end
end
