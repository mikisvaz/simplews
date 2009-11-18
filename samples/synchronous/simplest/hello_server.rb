require 'simplews'

server = SimpleWS.new('HelloWS', 'Just greets you', 'localhost', 8081)

server.serve :hi, %w(name), :name => :string, :return => :string do |name|
  "Hi #{ name }"
end

server.start
