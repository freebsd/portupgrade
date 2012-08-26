
Dir.glob(File.join(File.dirname(__FILE__), 'test_*.rb')) { |file|
  require(file) unless file == __FILE__
}
