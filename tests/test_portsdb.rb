#!/usr/bin/env ruby
#
# $Id: test_portsdb.rb,v 1.1.1.1 2006/06/13 12:59:01 sem Exp $
$:.push("..")

require 'test/unit'

require 'pkgtools'
require 'pkgtools/pkgdb'
require 'pkgtools/portsdb'

class TestPortsDB < Test::Unit::TestCase
  def test_strip
    pkgdb = PkgDB.instance.setup('/var/db/pkg')
    portsdb = PortsDB.instance.setup(pkgdb.db_dir, '/usr/ports')

    assert_equal('foo/bar1', portsdb.strip('foo/bar1'))
    assert_equal('foo/bar2', portsdb.strip('foo/bar2/'))
    assert_equal('foo/bar3', portsdb.strip('/usr/ports/foo/bar3'))
    assert_equal('foo/bar4', portsdb.strip('/usr/ports/foo/bar4/'))
    assert_equal('foo/bar7', portsdb.strip('/usr/ports/foo//bar7/'))
    assert_equal(nil, portsdb.strip('/usr/ports/foo/../bar8/foo/'))
    assert_equal(nil, portsdb.strip('/usr/ports/foo/./bar9/'))
    assert_equal(nil, portsdb.strip('/usr/ports/foo/bar5/Makefile'))
    assert_equal(nil, portsdb.strip('/usr/ports/foo/bar6/files/'))
    assert_equal(nil, portsdb.strip('/foo'))
    assert_equal(nil, portsdb.strip('/foo/'))
    assert_equal(nil, portsdb.strip('/foo/bar'))
  end
end
