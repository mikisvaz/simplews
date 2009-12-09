# This file add support for Rake pipelines.

require 'simplews/jobs'
require 'rake'

class SimpleWS::Jobs::Scheduler::Job

  # Add step information to rule tasks, as the 'desc' method cannot be used to
  # describe them for the time being.
  def add_description(reg_exp, step, message)
    @step_descriptions ||= {}
    @step_descriptions[Regexp.new(reg_exp)] = "#{ step }: #{ message }"
  end

  # Instruct rake to load the rakefile, named Rakefile by default, and use it
  # to produce the file specified first as product of the web service task. The
  # 'execute' method of the Rake::Tasks class method execute is monkey-patched
  # to log the steps. Since this is executed on a new process, there should be
  # no side-effects from the patching.
  def rake(rakefile = "Rakefile")
    Rake::Task.class_eval <<-'EOC'
      alias_method :old_execute, :execute
      def execute(*args)
        action = name
        message = $_step_desriptions.collect{|rexp, msg| 
          if name.match(rexp)
            msg
          else
            nil
          end
        }.compact.first

        message ||= comment 

        message ||= "Invoking #{name}"

        if message.match(/^(\w+): (.*)/)
          $_current_job.step($1, $2)
        else
          $_current_job.step(name, message)
        end

        old_execute(*args)
      end
    EOC

    $step_descriptions = {}
    load rakefile
    $step_descriptions.each{|re, info|
      add_description(re, info[:step], info[:description])
    }
    files = result_filenames

    $_current_job = self
    $_step_desriptions = @step_descriptions || {}
    Rake::Task[files.first].invoke
  end

end

