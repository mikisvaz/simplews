require 'rubygems'
require 'simplews'

s = SimpleWS.new do
  serve :hello_world do puts "Hello World" end
end

puts s.wsdl

