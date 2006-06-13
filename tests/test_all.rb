# $Id: test_all.rb,v 1.1 2002/12/07 11:32:04 knu Exp $

Dir.glob(File.join(File.dirname(__FILE__), 'test_*.rb')) { |file|
  require(file) unless file == __FILE__
}
