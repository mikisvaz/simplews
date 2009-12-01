require 'simplews/jobs'
require 'simplews/rake'


class TestWS < SimpleWS::Jobs

  task :name, %w(name), {:name => :string, :results => :string}, ['name/{JOB}'] do |name|
    $name = name
    rake
  end

  task :age, %w(age), {:age => :string, :results => :string}, ['age/{JOB}'] do |age|
    $age = age
    rake
  end




end

FileUtils.mkdir 'work/name' unless File.exist? 'work/name'


t = Thread.new{
  TestWS.new('T','T', 'localhost', '8081', 'work').start
}

driver = SimpleWS.get_driver('http://localhost:8081','T')

job = driver.name('Miguel', '')


while !driver.done(job)
  puts "======="
  puts driver.status(job)
  puts "--"
  puts driver.messages(job)
  puts "--"
  sleep 1
end

puts driver.status(job)
puts driver.messages(job)
p driver.results(job)
puts driver.result(driver.results(job).first)

t.join

