require File.dirname(__FILE__) + '/test_helper.rb'


class TestSimpleWS < Test::Unit::TestCase

  class TestWS < SimpleWS
    def hi(name)
      "Hi #{name}, how are you?"
    end

    def initialize(*args)
      super(*args)
      serve :hi, %w(name), :name => :string, :return => :string

      serve :bye, %w(name), :name => :string, :return => :string do |name|
          "Bye bye #{name}. See you soon."
      end

    end
  end


  def setup
    server = TestWS.new("TestWS", "Greeting Services", 'localhost', port)
    server.wsdl("TestWS.wsdl")

    Thread.new do
      server.start
    end

  end

  def test_client
    require 'soap/wsdlDriver'
    driver = SOAP::WSDLDriverFactory.new( "TestWS.wsdl").create_rpc_driver
    assert(driver.hi('Gladis') == "Hi Gladis, how are you?")
    assert(driver.bye('Gladis') == "Bye bye Gladis. See you soon.")

    
    driver = SimpleWS::get_driver('http://localhost:' + port, "TestWS")
    assert(driver.hi('Gladis') == "Hi Gladis, how are you?")
    assert(driver.bye('Gladis') == "Bye bye Gladis. See you soon.")


    require 'fileutils'
    FileUtils.rm 'TestWS.wsdl'
  end



end
