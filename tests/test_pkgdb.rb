#!/usr/bin/env ruby
#
# $FreeBSD: projects/pkgtools/tests/test_pkgdb.rb,v 1.3 2009-10-27 23:30:14 stas Exp $
$:.push("..")

require 'find'

require 'test/unit'

require 'pkgtools'
require 'pkgtools/pkgdb'

init_pkgtools_global

class TestPkgDB < Test::Unit::TestCase
  def test_strip
    pwd = Dir.pwd

    pkgdb = PkgDB.instance.setup('/var/db/pkg')
    test_pkgname = ''

    # Find any installed package
    if `make -f /usr/ports/Mk/bsd.port.mk -V WITH_PKGNG`.chomp != ""
	    test_pkgname = `pkg query '%n-%v'|head -n 1`.chomp
    else
	    Find.find('/var/db/pkg') do |path|
	      if FileTest.directory?(path)
		test_pkgname = File.basename(path)
	      end
	    end
    end

    assert_equal('foo1', pkgdb.strip('foo1'))
    assert_equal('foo2', pkgdb.strip('foo2/'))

    assert_equal('bar/foo', pkgdb.strip('bar/foo'))
    assert_equal(nil, pkgdb.strip('baz/bar/foo'))
    assert_equal(nil, pkgdb.strip('/baz/bar/foo'))

    assert_equal(test_pkgname, pkgdb.strip(test_pkgname, true))

    assert_equal(nil, pkgdb.strip('./' + test_pkgname, true))

    Dir.chdir(pkgdb.db_dir)

    assert_equal('foo3', pkgdb.strip('/var/db/pkg/foo3'))
    assert_equal('foo4', pkgdb.strip('/var/db/pkg/foo4/'))
    assert_equal('foo5', pkgdb.strip('foo5'))
    assert_equal('foo6', pkgdb.strip('foo6/'))

    assert_equal(nil, pkgdb.strip('/var/db/pkg/foo/bar', true))
    assert_equal(nil, pkgdb.strip('/var/db/pkg/', true))
    assert_equal(nil, pkgdb.strip('/var/db/pkg/.', true))
    assert_equal(nil, pkgdb.strip('/foo', true))
    assert_equal(nil, pkgdb.strip('/foo/bar', true))

    assert_equal(test_pkgname, pkgdb.strip(test_pkgname, true))
    assert_equal(test_pkgname, pkgdb.strip('/var/db/pkg/' + test_pkgname, true))

    assert_equal(nil, pkgdb.strip('../' + test_pkgname, true))
  ensure
    Dir.chdir(pwd)
  end
end
