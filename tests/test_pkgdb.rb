#!/usr/bin/env ruby
#
# $Id: test_pkgdb.rb,v 1.1.1.1 2006/06/13 12:59:01 sem Exp $
$:.push("..")

require 'find'

require 'test/unit'

require 'pkgdb'

class TestPkgDB < Test::Unit::TestCase
  def test_strip
    pwd = Dir.pwd

    pkgdb = PkgDB.instance.setup('/var/db/pkg')
    ruby_pkgname = ''
    Find.find('/var/db/pkg') do |path|
      if FileTest.directory?(path) && /ruby-1.9/ =~ path
	ruby_pkgname = File.basename(path)
      end
    end

    assert_equal('foo1', pkgdb.strip('foo1'))
    assert_equal('foo2', pkgdb.strip('foo2/'))

    assert_equal('bar/foo', pkgdb.strip('bar/foo'))
    assert_equal(nil, pkgdb.strip('baz/bar/foo'))
    assert_equal(nil, pkgdb.strip('/baz/bar/foo'))

    assert_equal(ruby_pkgname, pkgdb.strip(ruby_pkgname, true))

    assert_equal(nil, pkgdb.strip('./' + ruby_pkgname, true))

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

    assert_equal(ruby_pkgname, pkgdb.strip(ruby_pkgname, true))
    assert_equal(ruby_pkgname, pkgdb.strip('/var/db/pkg/' + ruby_pkgname, true))

    assert_equal(nil, pkgdb.strip('../' + ruby_pkgname, true))
  ensure
    Dir.chdir(pwd)
  end
end
