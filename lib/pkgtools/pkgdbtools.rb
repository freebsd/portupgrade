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

module PkgDBTools
  def PkgDBTools.remove_lock(file_name, force = false)
    return if file_name.nil?

    if !file_name.nil? && File.exist?(file_name) && !File.zero?(file_name) &&
      file = File.open(file_name)

      pid, mode = file.gets.split(' ')
      file.close

      # Remove only our lock file unless force
      File.unlink(file_name) if pid.to_i == $$ || force
    end
  end

  def db_dir()
    unless @db_dir
      set_db_dir(nil)	# initialize with the default value
    end

    @db_dir
  end

  def db_driver()
    unless @db_driver
      set_db_driver(nil)	# initialize with the default value
    end

    @db_driver
  end

  def db_driver=(new_db_driver)
    begin
      case new_db_driver || ENV['PKG_DBDRIVER'] || 'bdb_btree'
      when 'bdb_btree'
	@db_driver = :bdb_btree
      when 'bdb_hash', 'bdb'
	@db_driver = :bdb_hash
      when 'bdb1_btree', 'btree'
	@db_driver = :bdb1_btree
      when 'bdb1_hash', 'hash', 'bdb1'
	@db_driver = :bdb1_hash
      else
	@db_driver = :dbm_hash
      end

      case @db_driver
      when :bdb_btree
	next_driver = 'bdb1_btree'
	require 'bdb'
	@db_params = ["set_pagesize" => 1024, "set_cachesize" => [0, 32 * 1024, 0]]
      when :bdb_hash
	next_driver = 'bdb1_hash'
	require 'bdb'
	@db_params = ["set_pagesize" => 1024, "set_cachesize" => [0, 32 * 1024, 0]]
      when :bdb1_btree
	next_driver = 'dbm'
	require 'bdb1'
	@db_params = ["set_pagesize" => 1024, "set_cachesize" => 32 * 1024]
      when :bdb1_hash
	next_driver = 'dbm'
	require 'bdb1'
	@db_params = ["set_pagesize" => 1024, "set_cachesize" => 32 * 1024]
      else
	next_driver = nil
	require 'dbm'
      end
    rescue LoadError
      if next_driver.nil?
	raise DBError, "No driver is available!"
      end

      new_db_driver = next_driver
      retry
    end

    @db_driver
  end
  alias set_db_driver db_driver=

  def date_db_file
    File.mtime(@db_file) rescue Time.at(0)
  end

  def check_db_version
    file_db_version = Marshal.load(@db[':db_version'])

    file_db_version[0] == @db_version[0] && file_db_version[1] >= @db_version[1]
  rescue => e
    return false
  end

  def lock_db_on_read
    return if @lock_file.nil?
    count = 0
    while FileTest.exist?(@lock_file)
      if Time::now() - File.stat(@lock_file).mtime > 120
	puts "** Stale lock file was found. Removed."
	PkgDBTools.remove_lock(@lock_file, true)
	break
      end
      sleep 1 if File.zero?(@lock_file)
      file = File.open(@lock_file)
      pid, mode = file.gets.chomp.split(' ')
      file.close
      if mode == 'w' 
	if count == 0
	  puts "** Database file locked for writing. Waiting."
	end
	sleep 1
	count += 1
	if count > 120
	  puts "** Timeout. The lock looks dead. Remove it."
	  PkgDBTools.remove_lock(@lock_file, true)
	end
      else
	# ignore read lock
	break
      end
    end

    file = File.open(@lock_file, "w")
    file.puts "#$$ r"
    file.close
  end

  def lock_db_on_write
    return if @lock_file.nil?
    count = 0
    while FileTest.exist?(@lock_file)
      if Time::now() - File.stat(@lock_file).mtime > 120
	STDERR.puts "** Stale lock file was found. Removed."
	PkgDBTools.remove_lock(@lock_file, true)
	break
      end
      if count == 0
	STDERR.puts "** Database file locked. Waiting."
      end
      sleep 1
      count += 1
      if count > 120
	STDERR.puts "** Timeout. The lock looks dead. Remove it."
	PkgDBTools.remove_lock(@lock_file, true)
      end
    end

    file = File.open(@lock_file, "w")
    file.puts "#$$ w"
    file.close
  end

  def unlock_db
    PkgDBTools.remove_lock(@lock_file)
  end

  def get_db(mode, perm)
    case db_driver
    when :bdb_btree
      db = BDB::Btree.open @db_file, nil, mode, perm, *@db_params
    when :bdb_hash
      db = BDB::Hash.open @db_file, nil, mode, perm, *@db_params
    when :bdb1_btree
      db = BDB1::Btree.open @db_file, mode, perm, *@db_params
    when :bdb1_hash
      db = BDB1::Hash.open @db_file, mode, perm, *@db_params
    else
      if mode == 'w+'
	File.unlink(@db_file) if File.exist?(@db_file)
      end
      db = DBM.open(@db_filebase)
    end
    db
  end

  def open_db_for_read!
    close_db

    lock_db_on_read
    @db = get_db('r', 0)
  end

  def open_db_for_update!
    close_db

    lock_db_on_write
    @db = get_db('r+', 0664)
  end

  def open_db_for_rebuild!
    close_db

    lock_db_on_write
    @db = get_db('w+', 0664)
  end

  def close_db
    unlock_db
    if @db
      @db.close
      @db = nil
    end
  end

  module_function :db_dir, :db_driver, :set_db_driver,
    :check_db_version, :open_db_for_read!, :open_db_for_update!,
    :open_db_for_rebuild!, :close_db
  public :db_dir, :close_db
end

