require 'rubygems'
gem 'soap4r'
require 'soap/rpc/standaloneServer'
require 'builder'


# SimpleWS is a class that wraps SOAP::RPC::StandaloneServer to ease the
# implementation of Web Services, specifically the generation of the
# +WSDL+ file. It provides a particular syntax that allows to specify
# the methods that are going to be served along with the types of the
# parameters and of the response so that the +WSDL+ can be generated
# accordingly. Actual Servers can be instances of this class where
# methods are assigned dynamically or of classes that extend SimpleWS.
#   class TestWS < SimpleWS
#    def hi(name)
#      "Hi #{name}, how are you?"
#    end
#
#    def initialize(*args)
#      super(*args)
#      serve :hi, %w(name), :name => :string, :return => :string
#
#      serve :bye, %w(name), :name => :string, :return => :string do |name|
#          "Bye bye #{name}. See you soon."
#      end
#
#    end
#  end
#
#  # Creating a server and starting it
#  
#  server = TestWS.new("TestWS", "Greeting Services", 'localhost', '1984') 
#  server.wsdl("TestWS.wsdl")
#
#  Thread.new do
#     server.start
#  end
#
#  # Client code. This could be run in another process.
#
#  driver = SimpleWS::get_driver('http://localhost:1984', "TestWS")
#  puts driver.hi('Gladis')  #=> "Hi Gladis, how are you?"
#  puts driver.bye('Gladis') #=> "Bye bye Gladis. See you soon."
#



class SimpleWS <  SOAP::RPC::StandaloneServer
  # Saves method defined in the class to be served by the instances
  INHERITED_METHODS    = {} unless defined? INHERITED_METHODS

  # This is a helper function for clients. Given the +url+ where the
  # server is listening, as well as the name of the server, it can
  # manually access the +wsdl+ function and retrieve the complete +WSDL+
  # file. This works *only* in web servers of class SimpleWS, not on
  # the general SOAP::RPC::StandaloneServer or any other type of web
  # server.
  def self.get_wsdl(url, name)
     require 'soap/rpc/driver'
     driver = SOAP::RPC::Driver.new(url, "urn:#{ name }")
     driver.add_method('wsdl')
     driver.wsdl
  end

  # Builds on the get_wsdl function to provide the client with a
  # reference to the driver. Again, only works with SimpleWS servers.
  def self.get_driver(url, name)
    require 'soap/wsdlDriver'
    require 'fileutils'

    tmp = File.open("/tmp/simpleWS.wsdl",'w')
    tmp.write SimpleWS::get_wsdl(url, name)
    tmp.close
    driver = SOAP::WSDLDriverFactory.new( "/tmp/simpleWS.wsdl"  ).create_rpc_driver
    FileUtils.rm "/tmp/simpleWS.wsdl"

    driver
  end

  attr_accessor :description

  # Creates an instance of a Server. The parameter +name+ specifies the
  # +namespace+ used in the +WSDL+, +description+ is the description
  # also included in the +WSDL+. The parameters +host+ and +port+,
  # specify where the server will be listening, they are parameters of
  # the +super+ class SOAP::RPC::StandaloneServer, they are made
  # explicit here because they are included in the +WSDL+ as well.
  def initialize(name=nil, description=nil, host=nil, port=nil, *args, &block)
    name ||= self.class.to_s
    description ||= "Web Server for #{ name }"
    host ||= "localhost"
    port ||= "1984"

    super(description, "urn:#{ name }", host, port, *args)

    @host        = host
    @port        = port
    @name        = name
    @description = description
    @messages    = []
    @operations  = []
    @bindings    = []
    @method_descriptions = {}
    @method_order        = []

    if block_given?
      instance_eval &block
    end

    puts "Server #{ name } at #{ host }:#{ port }"
    
 
    desc "Return the WSDL describing the web server"
    param_desc :return => "WSDL description"
    serve :wsdl, %w(),  :return => :string

    desc "Return HMLT table with documentation for the web service"
    param_desc :return => "HTML table with documentation"
    serve :documentation, %w(),  :return => :string

    INHERITED_METHODS.each{|name, info|
      @@last_description = info[:description]
      @@last_param_description = info[:param_descriptions]
      serve name, info[:args], info[:types], &info[:block]
    }
  end

  def name=(name)
    @name = name
    appname = name
    default_namespace = "urn:#{name}"
  end

  # Add a description for the next method served.
  @@last_description = nil
  @@last_param_description = nil
  def desc(text = "")
    @@last_description = text
  end

  # Add descriptions for the parameters of the next method served
  def param_desc(param_descriptions = {})
    @@last_param_description = {} 
    param_descriptions.each{|param, description| @@last_param_description[param.to_s] = description}
  end

  # Add a description for the next method served defined in at the class level
  def self.desc(text = "")
    @@last_description = text
  end

  # Add descriptions for the parameters of the next method served at the class
  # level
  def self.param_desc(param_descriptions = {})
    @@last_param_description = {} 
    param_descriptions.each{|param, description| @@last_param_description[param.to_s] = description}
  end

  # This method tells the server to provide a method named by the +name+
  # parameter, with arguments listed in the +args+ parameter. The
  # +types+ parameter specifies the types of the arguments as will be
  # described in the +WSDL+ file (see the TYPES2WSDL constant). The
  # actual method called will be the one with the same name. Optionally
  # a block can be provided, this block will be used to define a
  # function named as in name.
  #
  # If the method returns something, then the type of the return value
  # must be specified in the +types+ parameter as :return. If not value
  # for :return parameter is specified in the +types+ parameter the
  # method is taken to return no value. Other than that, if a parameter
  # type is omitted it is taken to be :string.
  def serve(name, args=[], types={}, &block)

    @method_descriptions[name] = {:args => args, :types => types, :block => block, 
      :description => @@last_description, :param_descriptions => @@last_param_description}
    
    @@last_description = nil
    @@last_param_description = nil

    @method_order << name
    if block
      inline_name = "_inline_" + name.to_s
      add_to_ruby(inline_name, &block)
      add_method_as(self,inline_name, name.to_s,*args)
    else
      add_method(self,name.to_s,*args)
    end

    add_to_wsdl(name, args, types)

    nil
  end

  # Saves the method to be served by the instances. The initialization of an
  # instance check if there where any methods declared to be served in the class
  # and add them.
  def self.serve(name, args=[], types={}, &block)
    INHERITED_METHODS[name] = {:args => args, :types => types, :block => block, 
      :description => @@last_description, :param_descriptions => @@last_param_description}
    @@last_description = nil
    @@last_param_description = nil
  end

  # If +filename+ is specified it saves the +WSDL+ file in that file. If
  # no +filename+ is specified it returns a string containing  the
  # +WSDL+. The no parameter version is served by default, so that
  # clients can use this method to access the complete +WSDL+ file, as
  # used in get_wsdl and get_driver.
  def wsdl(filename = nil)
    wsdl = WSDL_STUB.dup
    wsdl.gsub!(/\$\{MESSAGES\}/m,@messages.join("\n"))
    wsdl.gsub!(/\$\{OPERATIONS\}/m,@operations.join("\n"))
    wsdl.gsub!(/\$\{BINDINGS\}/m,@bindings.join("\n"))
    wsdl.gsub!(/\$\{NAME\}/,@name)
    wsdl.gsub!(/\$\{DESCRIPTION\}/,@description)
    wsdl.gsub!(/\$\{LOCATION\}/,"http://#{ @host }:#{ @port }")
    
    if filename
      directory = File.dirname(File.expand_path(filename))
      FileUtils.mkdir_p directory unless File.exists? directory
      File.open(filename,'w') {|f| f.write wsdl }
      nil
    else
      wsdl
    end
  end

  def documentation(filename = nil)
    html_table =  Builder::XmlMarkup.new(:indent => 2).table :class => "WS_documentation" do |xml|
      xml.thead do 
        xml.tr do
          xml.th "Operation", :class => "WS_operation" 
          xml.th "Parameters", :class => "WS_parameters"
          xml.th "Documentation", :class => "WS_documentation" 
        end
      end
      xml.tbody do
        @method_order.each do |method|
          desc = @method_descriptions[method][:description] || ""
          case
          when method.to_s == 'wsdl' || method.to_s == 'documentation'
            type = 'WS_documentation'
          when desc =~ /^Job management:/
            type = 'WS_job_management'
          when @method_descriptions[method][:args].include?( :sugested_name )
            type = 'WS_task'
          else
            type = 'WS_normal'
          end
          xml.tr :class => type, :id => "WS_method_#{method}" do
            xml.td method.to_s, :class => "WS_operation" 

            xml.td :class => "WS_parameters" do
              description = @method_descriptions[method]
              method_parameters = description[:args]
              method_parameters += ['return'] unless  description[:types][:return] == false || description[:types]['return'] == false
              if method_parameters.any?
                xml.dl :class => "WS_parameter_documentation" do
                  method_parameters.each do |param|
                    if param.to_s == 'return'
                      xml.dt param, :class => 'WS_return' 
                    else
                      xml.dt param
                    end
                    
                    if description[:param_descriptions]
                      xml.dd description[:param_descriptions][param.to_s] || "" 
                    else
                      xml.dd
                    end
                  end
                end
              end
            end
            xml.td desc, :class => "WS_documentation" 
          end
        end
      end
    end

    if filename
      directory = File.dirname(File.expand_path(filename))
      FileUtils.mkdir_p directory unless File.exists? directory
      File.open(filename,'w') {|f| f.write html_table }
      nil
    else
      html_table
    end
  end

  private

  def add_to_ruby(name, &block)
    self.class.send(:define_method, name, block)
  end

  def add_to_wsdl(name, args, types)
    description = @method_descriptions[name]
    message =  Builder::XmlMarkup.new(:indent => 2).message :name => "#{ name }Request" do |xml|
      
      args.each do |param|
        type = types[param.to_s] || types[param.to_sym] || :string
        type = type.to_sym

        xml.part :name => param, :type => TYPES2WSDL[type] do
          param_descriptions = description[:param_descriptions]

          if param_descriptions && param_descriptions[param.to_s]
            xml.documentation  param_descriptions[param.to_s]
          end
        end

      end
    end
    @messages << message

    message =  Builder::XmlMarkup.new(:indent => 2).message :name => "#{ name }Response" do |xml|
      type = [types[:return], types["return"]].compact.first 
      type = :string if type.nil? 
      if type
        type = type.to_sym
        xml.part :name => 'result', :type => TYPES2WSDL[type] do
          param_descriptions = description[:param_descriptions]

          if param_descriptions && param_descriptions['return']
            xml.documentation  param_descriptions['return']
          end
        end
      end
    end
    @messages << message

    operation = Builder::XmlMarkup.new(:indent => 2).operation :name => "#{ name }" do |xml|
      xml.documentation description[:description]  if description[:description]
      xml.input :message => "tns:#{ name }Request"
      xml.output :message => "tns:#{ name }Response"
    end

    @operations << operation

    binding = Builder::XmlMarkup.new(:indent => 2).operation :name => "#{ name }" do |xml|
      xml.tag! 'soap:operation'.to_sym, :soapAction => "urn:${NAME}##{name}", :style => 'rpc'
      xml.input do |xml|
        xml.tag! 'soap:body'.to_sym, :namespace => "urn:${NAME}", :encodingStyle => "http://schemas.xmlsoap.org/soap/encoding/", :use => "encoded"
      end                                                                                                                                         
      xml.output do |xml|                                                                                                                         
        xml.tag! 'soap:body'.to_sym, :namespace => "urn:${NAME}", :encodingStyle => "http://schemas.xmlsoap.org/soap/encoding/", :use => "encoded"
      end
    end

    @bindings << binding
  end


  if ! defined? WSDL_STUB
  WSDL_STUB =<<EOT
<?xml version="1.0"?>
<definitions xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" 
xmlns:tns="${NAME}-NS"
xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" 
xmlns:si="http://soapinterop.org/xsd" 
xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" 
xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
xmlns="http://schemas.xmlsoap.org/wsdl/" 
targetNamespace="${NAME}-NS">


   <types>
      <schema xmlns="http://www.w3.org/2001/XMLSchema"
         targetNamespace="${NAME}-NS"
         xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
         xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
         <complexType name="ArrayOfString">
            <complexContent>
               <restriction base="soapenc:Array">
                  <attribute ref="soapenc:arrayType" 
                  wsdl:arrayType="string[]"/>
               </restriction>
            </complexContent>
         </complexType>
       </schema>
   </types>

${MESSAGES}
<portType name="${NAME}">
${OPERATIONS}
</portType>

<binding name="${NAME}Binding" type="tns:${NAME}">
   <soap:binding style="rpc" transport="http://schemas.xmlsoap.org/soap/http"/>
${BINDINGS}
</binding>
<service name="${NAME}">
    <documentation>${DESCRIPTION}</documentation>
 
    <port name="${NAME}" binding="tns:${NAME}Binding">
       <soap:address location="${LOCATION}"/>
    </port>
</service>

</definitions>
EOT
  end

  if ! defined? TYPES2WSDL
    TYPES2WSDL = {
      :boolean => 'xsd:boolean',
      :string  => 'xsd:string',
      :integer => 'xsd:integer',
      :float   => 'xsd:float',
      :array   => 'tns:ArrayOfString',
      :binary  => 'xsd:base64Binary',
    }
  end


end


