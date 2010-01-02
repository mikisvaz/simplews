require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'simplews'
require 'simplews/jobs'

require 'base64'

class Test::Unit::TestCase
  def port
    '2100'
  end
end
