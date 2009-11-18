require 'soap/wsdlDriver'

client = SOAP::WSDLDriverFactory.new( "BirthdayWS.wsdl").create_rpc_driver

puts client.message

puts client.greet('Mike', 32)

%w(Mike Lisa).each do |name|
  if client.greeted name
    puts "I greeted #{ name }"
  else
    puts "I did not greet #{ name }"
  end
end



