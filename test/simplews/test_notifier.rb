require File.dirname(File.dirname(__FILE__)) + '/test_helper.rb' 

require 'simplews/notifier'
require 'soap/wsdlDriver'

MAIL="change.to@your.mail.com"

WSDL_FILE='TestMonitor_Simplews.wsdl'

class TestMonitor < Test::Unit::TestCase
  @@server = SimpleWS::Jobs.new do
    task :test, %w(fail), {:fail => :boolean},[] do |do_fail|
      step(:one, "One")
      sleep 2
      step(:two, "Two")
      if do_fail
        raise "Failed"
      end
    end
  end

  @@server.wsdl WSDL_FILE


  @@monitor = SimpleWS::Jobs::Notifier.new("Test", "localhost:1984", WSDL_FILE, :smtp_host => 'ucsmtp.ucm.es', :filename => '/tmp/monitor.marshal')

  @@driver = SOAP::WSDLDriverFactory.new(WSDL_FILE).create_rpc_driver

  @@monitor.start
  Thread.new do
    @@server.start
  end

  #FileUtils.rm WSDL_FILE
  
  def test_error
    @@monitor.error("job-1", MAIL, 'Test Error')
  end

  def test_success
    @@monitor.success("job-1", MAIL)
  end

  def test_cicle_success
   job = @@driver.test(false, '')
   @@monitor.add_job(job, MAIL)

   while @@monitor.pending?
     sleep 10
   end
  end

  def test_cicle_error
   job = @@driver.test(true, '')
   @@monitor.add_job(job, MAIL)

   while @@monitor.pending?
     sleep 10
   end
  end


end
