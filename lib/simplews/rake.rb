# This file add support for Rake pipelines.

require 'simplews/jobs'
require 'rake'

class SimpleWS::Jobs::Scheduler::Job

  def rake(rakefile = "Rakefile")
    $_current_job = self
    Rake::Task.class_eval <<-'EOC'
      alias_method :old_invoke, :invoke
      def invoke
        if comment.match(/^(\w+): (.*)/)
          $_current_job.step($1, $2)
        else
          $_current_job.step(name, comment)
        end
        old_invoke
      end
    EOC

    load rakefile
    files = SimpleWS::Jobs::Scheduler::Job.job_info(job_name)[:results]
    Rake::Task[files.first].invoke
  end

end

