require 'simplews'


client = SimpleWS::get_driver('http://localhost:8081', 'HelloWS')

puts client.hi 'Mike'

