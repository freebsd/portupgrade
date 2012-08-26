#!/usr/bin/env ruby
#
$:.push("..")

require 'test/unit'

require 'pkgtools/pkgversion'

class TestPkgVersion < Test::Unit::TestCase
  def test_s_new
    ver = PkgVersion.new('2.3.10a')
    assert_equal(['2.3.10a', 0, 0], [ver.version, ver.revision, ver.epoch])

    ver = PkgVersion.new('2.3.10a_1')
    assert_equal(['2.3.10a', 1, 0], [ver.version, ver.revision, ver.epoch])

    ver = PkgVersion.new('2.3.10a_1,2')
    assert_equal(['2.3.10a', 1, 2], [ver.version, ver.revision, ver.epoch])

    assert_raises(ArgumentError) { PkgVersion.new(nil) }
    assert_raises(ArgumentError) { PkgVersion.new('') }
    assert_raises(ArgumentError) { PkgVersion.new('1 2') }
    assert_raises(ArgumentError) { PkgVersion.new('_5') }
    assert_raises(ArgumentError) { PkgVersion.new(',2') }
    assert_raises(ArgumentError) { PkgVersion.new('_5,2') }
    assert_raises(ArgumentError) { PkgVersion.new('1.3_2_5') }
    assert_raises(ArgumentError) { PkgVersion.new('1.3_a') }
    assert_raises(ArgumentError) { PkgVersion.new('1.3_2,a') }
    assert_raises(ArgumentError) { PkgVersion.new('1.3,a') }
  end

  def test_to_s
    assert_equal('2.3.10a', PkgVersion.new('2.3.10a').to_s)
    assert_equal('2.3.10a_1', PkgVersion.new('2.3.10a_1').to_s)
    assert_equal('2.3.10a,2', PkgVersion.new('2.3.10a,2').to_s)
    assert_equal('2.3.10a_1,2', PkgVersion.new('2.3.10a_1,2').to_s)
  end

  def test_coerce
    ver = PkgVersion.new('1')

    assert_raises(TypeError) { ver.coerce(0.10) }
    assert_equal(PkgVersion.new('0.10'), ver.coerce('0.10')[0])
    assert_equal(PkgVersion.new('0.10'), ver.coerce(PkgVersion.new('0.10'))[0])
  end

  def test_compare
    assert_equal(PkgVersion.new('1.0'), PkgVersion.new('1.0'))
    assert_equal(PkgVersion.new('2.15a'), PkgVersion.new('2.15a'))
    assert_operator(PkgVersion.new('0.10'), :>, PkgVersion.new('0.9'))
    assert_raises(ArgumentError) { '0.10' > PkgVersion.new('0.9') }
    assert_operator(PkgVersion.new('0.9'), :<, '0.10')
    assert_raises(TypeError) { PkgVersion.new('0.9') > 0.8 }
    assert_raises(ArgumentError) { 0.8 < PkgVersion.new('0.9') }
    assert_operator(PkgVersion.new('2.3p10'), :>, PkgVersion.new('2.3p9'))
    assert_operator(PkgVersion.new('1.6.0'), :>, PkgVersion.new('1.6.0.p3'))
    assert_operator(PkgVersion.new('1.0.b'), :>, PkgVersion.new('1.0.a3'))
    assert_operator(PkgVersion.new('1.0a'), :>, PkgVersion.new('1.0'))
    assert_operator(PkgVersion.new('1.0a'), :<, PkgVersion.new('1.0b'))
    assert_operator(PkgVersion.new('5.0a'), :>, PkgVersion.new('5.0.b'))

    assert_operator(PkgVersion.new('1.5_1'), :>, PkgVersion.new('1.5'))
    assert_operator(PkgVersion.new('1.5_2'), :>, PkgVersion.new('1.5_1'))
    assert_operator(PkgVersion.new('1.5_1'), :<, PkgVersion.new('1.5.0.1'))
    assert_operator(PkgVersion.new('00.01.01,1'), :>, PkgVersion.new('99.12.31'))
    assert_operator(PkgVersion.new('0.0.1,2'), :>, PkgVersion.new('00.01.01,1'))

    assert_operator(PkgVersion.new('0.0.1_1,2'), :>, PkgVersion.new('0.0.1,2'))
    assert_operator(PkgVersion.new('0.0.1_1,3'), :>, PkgVersion.new('0.0.1_2,2'))

    assert_operator(PkgVersion.new('2.0.2'), :>, PkgVersion.new('2.00'))
    assert_equal(PkgVersion.new('3'), PkgVersion.new('3.0'))
    assert_operator(PkgVersion.new('4a'), :<, PkgVersion.new('4a0'))
    assert_equal(PkgVersion.new('10a1b2'), PkgVersion.new('10a1.b2'))

    assert_equal(PkgVersion.new('7pl'), PkgVersion.new('7.pl'))
    assert_equal(PkgVersion.new('8.0.a'), PkgVersion.new('8.0alpha'))
    assert_equal(PkgVersion.new('9.b3.0'), PkgVersion.new('9beta3'))
    assert_equal(PkgVersion.new('10.pre7'), PkgVersion.new('10.pre7.0'))
    assert_equal(PkgVersion.new('11.r'), PkgVersion.new('11.rc'))

    assert_operator(PkgVersion.new('12pl'), :<, PkgVersion.new('12alpha'))
    assert_operator(PkgVersion.new('13pl3'), :<, PkgVersion.new('13alpha'))

    assert_equal(PkgVersion.new('1.0.0+2003.09.06'), PkgVersion.new('1.0+2003.09.06'))
    assert_operator(PkgVersion.new('1.0.1+2003.09.06'), :>, PkgVersion.new('1.0+2003.09.06'))
    assert_operator(PkgVersion.new('1.0.0+2003.09.06'), :<, PkgVersion.new('1.0+2003.09.06_1'))
    assert_operator(PkgVersion.new('1.0.1+2003.09.06'), :>, PkgVersion.new('1.0+2003.09.06_1'))
    assert_operator(PkgVersion.new('1.0.1+2003.09.06'), :<, PkgVersion.new('1.0.1+2003.09.07'))
    assert_operator(PkgVersion.new('1.0.1+2003.09.07'), :>, PkgVersion.new('1.0.1+2003.09.06'))
  end

  def test_s_compare_versions
    assert_equal(0, PkgVersion.compare_numbers('2.15a', '2.15a'))
    assert_operator(PkgVersion.compare_numbers('0.10', '0.9'), :>, 0)
    assert_operator(PkgVersion.compare_numbers('2.3p10', '2.3p9'), :>, 0)
    assert_operator(PkgVersion.compare_numbers('1.6.0', '1.6.0.p3'), :>, 0)
    assert_operator(PkgVersion.compare_numbers('1.0.b', '1.0.a3'), :>, 0)
    assert_operator(PkgVersion.compare_numbers('1.0a', '1.0'), :>, 0)
    assert_operator(PkgVersion.compare_numbers('5.0a', '5.0.b'), :>, 0)
  end
end
