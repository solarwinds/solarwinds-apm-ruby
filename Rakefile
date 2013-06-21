require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'
require 'rspec/core/rake_task'
require 'appraisal'

RSpec::Core::RakeTask.new('spec')

Rake::TestTask.new do |t|
 t.libs << 'spec'
end

desc "Run tests"
task :default => :spec
task :test => :spec
