# This file add support for Rake pipelines.

require 'simplews/jobs'
require 'rake'

class SimpleWS::Jobs::Scheduler::Job

  def add_message(reg_exp, step, message)
    @step_messages ||= {}
    @step_messages[Regexp.new(reg_exp)] = "#{ step }: #{ message }"
  end

  def rake(rakefile = "Rakefile")
    $_current_job = self
    $_step_messages = @step_messages || {}
    Rake::Task.class_eval <<-'EOC'
      alias_method :old_execute, :execute
      def execute(*args)
        action = name
        message = $_step_messages.collect{|rexp, msg| 
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

    load rakefile
    files = SimpleWS::Jobs::Scheduler::Job.job_info(job_name)[:results]
    Rake::Task[files.first].invoke
  end

end

