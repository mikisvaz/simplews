require 'rmail'
require 'net/smtp'
require 'soap/wsdlDriver'
require 'simplews/jobs'

class SimpleWS::Jobs::Notifier

  def driver
    case
    when String === @ws
      if File.exists? @ws
        return SOAP::WSDLDriverFactory.new(@ws).create_rpc_driver
      end
    when Array === @ws
      return SimpleWS.get_driver(@ws[0], @ws[1])
    when SOAP::WSDLDriverFactory === @ws
      return @ws
    end

    raise "Do not know how to connect to driver"
  end

  def initialize(name, host, ws, options = {})
    @host = host
    @name   = name
    @ws     = ws
    @smtp_host  = options[:smtp_host] || 'localhost'
    @smtp_port  = options[:smtp_port] || 25
    @sleep_time = options[:sleep_time] || 2
    @filename   = options[:filename]
    
    if @filename && File.exists?(@filename)
      @jobs = Marshal.load(File.open(@filename))
    else
      @jobs = {}
    end
  end

  def add_job(job_id, email)
    @jobs[job_id] = email
    File.open(@filename, 'w') do |f| f.write Marshal.dump(@jobs) end if @filename
  end

  def delete_job(job_id)
    @jobs.delete(job_id)
    File.open(@filename, 'w') do |f| f.write Marshal.dump(@jobs) end if @filename
  end

  def process
    @jobs.each do |job_id, email|
      if driver.done job_id
        if driver.error job_id
          error(job_id, email, driver.messages(job_id).last)
        else
          success(job_id, email)
        end
        delete_job(job_id)
      end
    end
  end

  def send_mail(to, subject, body)
    puts "Sending mail to #{ to }: #{ subject }"
    message = RMail::Message.new

    from = "noreply@" + @host.sub(/:.*/,'')

    message.header['To'] = to
    message.header['From'] = from
    message.header['Subject'] = subject
    
    main = RMail::Message.new    
    main.body = body

    message.add_part(main)

    Net::SMTP.start(@smtp_host.chomp, @smtp_port.to_i) do |smtp|
      smtp.send_message message.to_s, from, to
    end
  end


  def error(job_id, email, msg)
    body =<<-EOF
Dear #{ @name } user:

You job with id '#{ job_id }' has finished with error message:

#{ msg }

URL: http://#{@host.chomp}/#{ job_id }

Note: Do not reply to this message, it is automatically generated.
    EOF
    send_mail(email, "#{@name} [ERROR]: #{ job_id }", body)
  end

  def success(job_id, email)
    body =<<-EOF
Dear #{ @name } user:

You job with id '#{ job_id }' has finished successfully:

URL: http://#{@host.chomp}/#{ job_id }

Note: Do not reply to this message, it is automatically generated.
    EOF
    send_mail(email, "#{@name} [SUCCESS]: #{ job_id }", body)
  end

  def pending?
    ! @jobs.empty?
  end

  def start
    puts "Starting Email notifier."
    puts "Name: #{ @name }"
    puts "Host: #{ @host }"
    puts "SMTP: #{ @smtp_host }"
    @thread = Thread.new do
      while true
        begin
          process
          sleep @sleep_time
        rescue
          puts $!.message
        end
      end
    end
  end

  def stop
    @thread.kill
  end
end
