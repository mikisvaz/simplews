require 'simplews/jobs'

class ProcessWS < SimpleWS::Jobs
  task :process, %w(code), {:code => :string}, ['code.txt', 'inverted.txt'] do |code|

    step(:step1, "Writing code to file")
    write('code.txt', code)
    sleep 2

    step(:step2, "Writing inverted code to file")
    write('inverted.txt', code.reverse)
    sleep 2

    step(:step3, "Doing some other computations")
    sleep 2
  end

end

server = ProcessWS.new("ProcessWS", 'Emulate some lengthy process that produces results in files', 'localhost', 8081, 'ProcessWS-tmpdir')

File.open('ProcessWS.wsdl', 'w'){|file| file.puts server.wsdl}

server.start
