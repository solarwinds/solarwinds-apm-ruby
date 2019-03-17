source 'https://rubygems.org'

group :development, :test do
  gem 'rake'
  gem 'minitest'
  gem 'minitest-reporters', '< 1.0.18'
  gem 'minitest-debugger', :require => false
  gem 'rack-test'
  gem 'puma'
  gem 'bson'
  gem 'webmock' if RUBY_VERSION >= '2.0.0'
  gem 'mocha'
  gem 'rubocop', require: false
  gem 'ruby-prof'
  gem 'benchmark-ips'
  gem 'ruby-debug',   :platforms =>  :jruby
  gem 'debugger',     :platform  =>  :mri_19
  gem 'byebug'
  gem 'get_process_mem'
  gem 'memory_profiler'
end

if defined?(JRUBY_VERSION)
  gem 'sinatra', :require => false
else
  gem 'sinatra'
end

gemspec
