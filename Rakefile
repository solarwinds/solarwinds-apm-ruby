#!/usr/bin/env rake

require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.verbose = true
  t.ruby_opts = []
  t.libs << "test"

  # Since we support so many libraries and frameworks, tests
  # runs are segmented into gemfiles that have different
  # sets and versions of gems (libraries and frameworks).
  #
  # Here we detect the Gemfile the tests are being run against
  # and load the appropriate tests.
  #
  case File.basename(ENV['BUNDLE_GEMFILE'])
  when /rails/
    # Pre-load rails to get the major version number
    require 'rails'
    t.test_files = FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_test.rb"]
  when /frameworks/
    t.test_files = FileList['test/frameworks/sinatra*_test.rb'] +
                   FileList['test/frameworks/padrino*_test.rb'] +
                   FileList['test/frameworks/grape*_test.rb']
  when /libraries/
    t.test_files = FileList['test/support/*_test.rb'] +
                   FileList['test/reporter/*_test.rb'] +
                   FileList['test/instrumentation/*_test.rb'] +
                   FileList['test/profiling/*_test.rb']
  end

  # t.ruby_opts << ['-w']
  if defined?(JRUBY_VERSION)
    t.ruby_opts << ["-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar"]
  end
end

desc "Build the gem's c extension"
task :compile do
  unless defined?(JRUBY_VERSION)
    puts "== Building the c extension against Ruby #{RUBY_VERSION}"

    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    cmd = [ Gem.ruby, 'extconf.rb']
    sh cmd.join(' ')
    sh '/usr/bin/env make'
    File.delete symlink if File.exist? symlink

    if File.exists? so_file
      File.symlink so_file, symlink
      Dir.chdir pwd
      puts "== Extension built and symlink'd to #{symlink}"
    else
      Dir.chdir pwd
      puts "!! Extension failed to build (see above).  Are the base TraceView packages installed?"
      puts "!! See https://support.appneta.com/cloud/installing-traceview"
    end
  else
    puts "== Nothing to do under JRuby."
  end
end

desc "Clean up extension build files"
task :clean do
  unless defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    sh '/usr/bin/env make clean'

    Dir.chdir pwd
  else
    puts "== Nothing to do under JRuby."
  end
end

desc "Remove all built files and extensions"
task :distclean do
  unless defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')
    mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')

    if File.exists? mkmf_log
      File.delete symlink if File.exist? symlink
      Dir.chdir ext_dir
      sh '/usr/bin/env make distclean'

      Dir.chdir pwd
    else
      puts "Nothing to distclean. (nothing built yet?)"
    end
  else
    puts "== Nothing to do under JRuby."
  end
end

desc "Rebuild the gem's c extension"
task :recompile => [ :distclean, :compile ]

task :console do
  require 'traceview/test'
  ENV['TRACEVIEW_GEM_VERBOSE'] = 'true'
  Bundler.require(:default, :development)
  TraceView::Config[:tracing_mode] = :always
  TV::Test.load_extras
  ARGV.clear
  Pry.start
end


