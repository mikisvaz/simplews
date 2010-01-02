require 'rubygems'
require 'simplews'
require 'base64'

server = SimpleWS.get_driver('http://localhost:1984', 'SimpleWS::Jobs')

job = server.reverse('Hello World!', '')

while not server.done(job)
  status = server.status(job)
  last_message = server.messages(job).last
  puts "#{ status }: #{ last_message }"
  sleep 1
end

raise "Error in job #{server.messages(job).last}" if server.error(job)

result_ids = server.results(job)

puts "--- Results"
puts "Original message: #{Base64.decode64 server.result(result_ids[1])}"
puts "Reverse message: #{Base64.decode64 server.result(result_ids[0])}"
puts "Length was: #{YAML.load(server.info(job))['length']}"
