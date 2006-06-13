#!/usr/bin/env ruby
#
# $Id: test_pkginfo.rb 1028 2004-07-20 11:14:02Z knu $
$:.push("..")

require 'test/unit'

require 'pkginfo'

class TestPkgInfo < Test::Unit::TestCase
  def test_s_new
    assert_raises(ArgumentError) { PkgInfo.new(nil) }
    assert_raises(ArgumentError) { PkgInfo.new('') }
    assert_raises(ArgumentError) { PkgInfo.new('foo=1.2') }
    assert_raises(ArgumentError) { PkgInfo.new('foo bar-1.2') }
    assert_raises(ArgumentError) { PkgInfo.new('-foo') }
    assert_raises(ArgumentError) { PkgInfo.new('foo-bar-') }
    assert_raises(ArgumentError) { PkgInfo.new('foo-1.2_1_1') }

    pkgname = PkgInfo.new('foo-bar-2.3.10a')
    assert_equal(['foo-bar', '2.3.10a', 0, 0], [pkgname.name, pkgname.version.version, pkgname.version.revision, pkgname.version.epoch])

    pkgname = PkgInfo.new('foo-bar-2.3.10a_1,2')
    assert_equal(['foo-bar', '2.3.10a', 1, 2], [pkgname.name, pkgname.version.version, pkgname.version.revision, pkgname.version.epoch])
  end

  def test_to_s
    assert_equal('foo-bar-2.3.10a', PkgInfo.new('foo-bar-2.3.10a').to_s)
    assert_equal('foo-bar-2.3.10a_1,2', PkgInfo.new('foo-bar-2.3.10a_1,2').to_s)
  end

  def test_coerce
    pkgname = PkgInfo.new('foo-1')

    assert_raises(TypeError) { pkgname.coerce(0.10) }
    assert_equal([PkgInfo.new('bar-2'), pkgname], pkgname.coerce('bar-2'))
    assert_equal([PkgInfo.new('bar-2'), pkgname], pkgname.coerce(PkgInfo.new('bar-2')))
    assert_equal([PkgVersion.new('2'), PkgVersion.new('1')], pkgname.coerce('2'))
    assert_equal([PkgVersion.new('2'), PkgVersion.new('1')], pkgname.coerce(PkgVersion.new('2')))
  end

  def test_compare
    assert_equal(PkgInfo.new('foo-bar-2.3.10a'), PkgInfo.new('foo-bar-2.3.10a'))
    assert_operator(PkgInfo.new('foo-baz-2.3.10a'), :>, PkgInfo.new('foo-bar-2.3.10a'))
    assert_operator(PkgInfo.new('foo-bar-2.3.10'), :>, PkgInfo.new('foo-bar-2.3.9'))
    assert_operator(PkgInfo.new('1foo-2.3.10'), :>, '2.3.9')
    assert_operator(PkgInfo.new('1foo-2.3.10'), :>, PkgVersion.new('2.3.9'))
    assert_operator(PkgInfo.new('1foo-2.3.10'), :>, '1foo-2.3.9')
  end

  def test_s_get_info
    
  end

  def test_match
    pkg = PkgInfo.new('foo-bar-1.2')

    assert(pkg.match?('foo-bar-1.2'))
    assert(!pkg.match?('foo-bar-1'))
    assert(pkg.match?('foo-bar'))
    assert(!pkg.match?('foo-bar-'))
    assert(!pkg.match?('foo'))
    assert(!pkg.match?('bar'))
    assert(!pkg.match?('bar-1.2'))
    assert(pkg.match?(/bar-[^\-]+$/))
  end
end
