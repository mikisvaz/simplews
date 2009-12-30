require File.dirname(__FILE__) + '/test_helper.rb'


class TestSimpleWS < Test::Unit::TestCase

  class TestWS < SimpleWS
    def hi(name)
      "Hi #{name}, how are you?"
    end

    desc "Say Hi"
    param_desc :name => "Who to say hi to", :return => "Salutation"
    serve :hi, %w(name), :name => :string, :return => :string
    def initialize(*args)
      super(*args)

      param_desc :name => "Who to say goodbye to", :return => "Parting :("
      serve :bye, %w(name), :name => :string, :return => :string do |name|
          "Bye bye #{name}. See you soon."
      end

    end
  end

  def setup
    $server = TestWS.new("TestWS", "Greeting Services", 'localhost', port)
    $server.wsdl("TestWS.wsdl")

    Thread.new do
      $server.start
    end
  end

  def teardown
    $server.shutdown
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


  def test_descriptions
    driver = SOAP::WSDLDriverFactory.new( "TestWS.wsdl").create_rpc_driver
    assert_match /Return the WSDL/, driver.wsdl
    assert_match /Say Hi/, driver.wsdl
  end

  def test_param_descriptions
    driver = SOAP::WSDLDriverFactory.new( "TestWS.wsdl").create_rpc_driver
    assert_match /Who to say hi/, driver.wsdl
    assert_match /Who to say goodbye/, driver.wsdl
    assert_match /Salutation/, driver.wsdl
    assert_match /Parting/, driver.wsdl
  end


end
