require 'rake'

# Include the step_dependencies and step_def methods to simplify Pipelines. Steps depend on
# the step strictly above by default. The output of the step is save marshaled,
# except for Strings which are save as text. The input of the step, the output
# of the previous step if availabe is accessed with the input method
#
# Example::
#
#     step_def :text do 
#       "Text to revert"
#     end
#
#     step_def :revert do
#       text = input
#       text.reverse
#     end
#
module Rake::Pipeline

  module Rake::Pipeline::Step

    class << self

      @@step_descriptions = {}
      def step_descriptions
        @@step_descriptions
      end

      def add_description(re, step, message)
        @@step_descriptions[re] = "#{ step }: #{ message }"                       
      end

      @@last_step = nil
      def step_dependencies(name, dependencies = nil)

        re = Regexp.new(/(?:^|\/)#{name}\/.*$/)

        # Take the last_description and associate it with the name
        if Rake.application.last_description
          add_description(re, name, Rake.application.last_description)
        end

        if dependencies.nil? && ! @@last_step.nil?
          dependencies = @@last_step
        end
        @@last_step = name

        # Generate the Hash definition
        case 
        when dependencies.nil?
          re
        when String === dependencies || Symbol === dependencies
          {re => lambda{|filename| filename.sub(name.to_s,dependencies.to_s) }}
        when Array === dependencies
          {re => lambda{|filename| dependencies.collect{|dep| filename.sub(name.to_s, dep.to_s) } }}
        when Proc === dependencies
          {re => dependencies}
        end

      end

      def parse_filename(filename)
        filename.match(/^(.*?)([^\/]*)\/([^\/]*)$/)
        {
          :prefix => $1,
          :step => $2,
          :job => $3,
        }
      end
    end
  end

  module Rake::Pipeline::Info

    def self.info_file(filename)
      info = Rake::Pipeline::Step.parse_filename(filename)
      "#{info[:prefix]}/.info/#{info[:job]}.yaml"
    end

    def self.load_info(t)
      filename = t.name
      info_filename = info_file(filename)

      if File.exists? info_filename
        YAML.load(File.open(info_filename))
      else
        {}
      end
    end

    def self.save_info(t, info = {})
      filename = t.name
      info_filename = info_file(filename)

      FileUtils.mkdir_p File.dirname(info_filename) unless File.exists? File.dirname(info_filename)
      File.open(info_filename,'w'){|file|
        file.write YAML.dump info
      }
    end
  end

  @@steps = []

  def steps
    @@steps
  end


  NON_ASCII_PRINTABLE = /[^\x20-\x7e\s]/
  def is_binary?(file)
    binary = file.read(1024) =~ NON_ASCII_PRINTABLE
    file.rewind
    binary
  end

  def step_descriptions
    Rake::Pipeline::Step.step_descriptions
  end


  def step_dependencies(*args)
    Rake::Pipeline::Step.step_dependencies(*args)
  end

  def infile(t, &block)
    File.open(t.prerequisites.first) do |f|
      block.call(f)
    end
  end

  def outfile(t, &block)
    File.open(t.name, 'w') do |f|
      block.call(f)
    end
  end

  def load_input(t, step = nil)
    if step
      info = Rake::Pipeline::Step.parse_filename(t.name)
      filename = "#{info[:prefix]}/#{step}/#{info[:job]}"
      File.open(filename){|f| 
        if is_binary?(f)
          Marshal.load(f) 
        else
          f.read
        end
      }
    else
      return nil if t.prerequisites.first.nil?
      infile(t){|f| 
        if is_binary?(f)
          Marshal.load(f) 
        else
          f.read
        end
      }
    end
  end

  def save_output(t, output)
    case 
    when output.nil?
      nil
    when String === output
      outfile(t){|f| f.write output } 
    else
      outfile(t){|f| f.write Marshal.dump(output) } 
    end

  end

  # We cannot load the input variable before the block.call, so we need another method

  # Load the input data from the previous step
  def input(step = nil)
    load_input(@@current_task, step) if @@current_task
  end

  if defined? SimpleWS::Jobs
    def method_missing(symbol, *args)
      $_current_job.send(symbol, *args)
    end
  else
    # Add values to the info file
    def info(values = {})
      puts "Using rake info"
      
      info = Rake::Pipeline::Info.load_info(@@current_task)
      info = info.merge values
      Rake::Pipeline::Info.save_info(@@current_task, info)
      info
    end
  end

  
  
  
  # Define a new step, it depends on the previously defined by default. It
  # saves the output of the block so it can be loaded by the input method of
  # the next step
  def step_def(name, dependencies = nil, &block)
    @@steps << name
    rule step_dependencies(name, dependencies) do |t| 

      # Save the task object to be able to load the input
      @@current_task = t
      
      output = block.call(t)
      
      save_output(t, output)
    end

  end
end

if __FILE__ == $0

  p Rake::Pipeline::Info.info_file('work/diseases/t')
end
