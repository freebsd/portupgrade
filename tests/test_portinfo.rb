#!/usr/bin/env ruby
#
# $Id: test_portinfo.rb 1028 2004-07-20 11:14:02Z knu $
$:.push("..")

require 'test/unit'

require 'pkgtools/ports'

class TestPortInfo < Test::Unit::TestCase
  SAMPLE1 = "ruby-perl-0.2.7|/usr/ports/lang/ruby-perl|/usr/local|A Ruby extension module to use the functions of Perl from Ruby|/usr/ports/lang/ruby-perl/pkg-descr|knu@FreeBSD.org|lang ruby perl5|ruby-1.6.2.2001.02.05|ruby-1.6.2.2001.02.05|http://www.yoshidam.net/Ruby.html#perl\n"
  SAMPLE2 = "ruby-byaccr-0.0_1|/usr/ports/devel/ruby-byaccr|/usr/local|Parser generator for ruby based on 'Berkeley Yacc' and 'Berkeley Yacc for Java'|/usr/ports/devel/ruby-byaccr/pkg-descr|knu@FreeBSD.org|devel ruby|||\n"

  def test_s_new
    assert_raises(ArgumentError) { PortInfo.new(nil) }
    assert_raises(ArgumentError) { PortInfo.new('baa') }

    portinfo = PortInfo.new(SAMPLE1)
    assert_equal(['ruby-perl', '0.2.7',
		 'lang/ruby-perl', 'lang/ruby-perl/pkg-descr',
		 '/usr/local', 'knu@FreeBSD.org',
		 'A Ruby extension module to use the functions of Perl from Ruby',
		 ['lang', 'ruby', 'perl5'],
		 ['ruby-1.6.2.2001.02.05'], ['ruby-1.6.2.2001.02.05'],
		 'http://www.yoshidam.net/Ruby.html#perl'],
		 [portinfo.pkgname.name, portinfo.pkgname.version.to_s,
		 portinfo.origin, portinfo.descr_file,
		 portinfo.prefix, portinfo.maintainer,
		 portinfo.comment,
		 portinfo.categories,
		 portinfo.build_depends, portinfo.run_depends,
		 portinfo.www])
    
    portinfo = PortInfo.new(SAMPLE2);
    assert_equal(['ruby-byaccr', '0.0_1',
		 'devel/ruby-byaccr', 'devel/ruby-byaccr/pkg-descr',
		 '/usr/local', 'knu@FreeBSD.org',
		 'Parser generator for ruby based on \'Berkeley Yacc\' and \'Berkeley Yacc for Java\'',
		 ['devel', 'ruby'],
		 [], [],
		 nil],
		 [portinfo.pkgname.name, portinfo.pkgname.version.to_s,
		 portinfo.origin, portinfo.descr_file,
		 portinfo.prefix, portinfo.maintainer,
		 portinfo.comment,
		 portinfo.categories,
		 portinfo.build_depends, portinfo.run_depends,
		 portinfo.www])
  end
  
  def test_to_s
    assert_equal(SAMPLE1, PortInfo.new(SAMPLE1).to_s)
    assert_equal(SAMPLE2, PortInfo.new(SAMPLE2).to_s)
  end
end
