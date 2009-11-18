require 'soap/wsdlDriver'

client = SOAP::WSDLDriverFactory.new( "ProcessWS.wsdl").create_rpc_driver

job_id = client.process "12345", ''

while not client.done job_id
  puts "Status: #{client.status job_id}"
  sleep 1
end

raise "Job #{ job_id } failed: #{client.messages(job_id).last}" if client.error job_id

results = client.results job_id

code = client.result results[0]
inverse = client.result results[1]

puts "Original code #{code}"
puts "Inverted code #{inverse}"


