require 'simplews'

class BirthdayWS < SimpleWS
  MESSAGE = "This is the BirthdayWS"

  serve :message , [] do 
    MESSAGE
  end


  def initialize(*args)
    super(*args)
    @greeted = []

    serve :greet, %w(name age), :name => :string, :age => :integer, :return => :string do |name, age|
      @greeted << name unless @greeted.include? name
      "Happy #{ age } birthday #{ name }"
    end

    serve :greeted, %w(name), :name => :string, :return => :boolean do |name|
      @greeted.include? name
    end
      
  end
end


server = BirthdayWS.new('BirthdayWS', 'Greets people on their birthday','localhost', 8081)

File.open('BirthdayWS.wsdl', 'w'){|file| file.puts server.wsdl}

server.start
