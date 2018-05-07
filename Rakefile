#!/usr/bin/env rake

require 'rubygems'
require 'fileutils'
require 'open-uri'
require 'bundler/setup'
require 'rake/testtask'
require 'appoptics_apm/test'

Rake::TestTask.new do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []
  t.libs << 'test'

  # Since we support so many libraries and frameworks, tests
  # runs are segmented into gemfiles that have different
  # sets and versions of gems (libraries and frameworks).
  #
  # Here we detect the Gemfile the tests are being run against
  # and load the appropriate tests.
  #
  case AppOpticsAPM::Test.gemfile
  when /delayed_job/
    require 'delayed/tasks'
    t.test_files = FileList['test/queues/delayed_job*_test.rb']
  when /rails/
    # Pre-load rails to get the major version number
    require 'rails'

    if Rails::VERSION::MAJOR == 5
      t.test_files = FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_test.rb"] +
                     FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_api_test.rb"]
    else
      t.test_files = FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_test.rb"]
    end

  when /frameworks/
    t.test_files = FileList['test/frameworks/sinatra*_test.rb'] +
                   FileList['test/frameworks/padrino*_test.rb'] +
                   FileList['test/frameworks/grape*_test.rb']
  when /libraries/
    t.test_files = FileList['test/support/*_test.rb'] +
                   FileList['test/reporter/*_test.rb'] +
                   FileList['test/instrumentation/*_test.rb'] +
                   FileList['test/profiling/*_test.rb'] -
                   ['test/instrumentation/twitter-cassandra_test.rb']
      # FIXME: exclude cassandra tests for now
      # TODO: they need refactoring to use the 'cassandra-driver' gem
      # ____  instead of the 'cassandra' gem, which hasn't had a commit since 09/2014
  when /instrumentation_mocked/
    # WebMock is interfering with other tests, so these have to run seperately
    t.test_files = FileList['test/mocked/*_test.rb']
  when /noop/
    t.test_files = FileList['test/noop/*_test.rb']
  end

  if defined?(JRUBY_VERSION)
    t.ruby_opts << ['-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar']
  end
end

desc "Fetch extension dependency files"
task :fetch_ext_deps do
  swig_version = %x{swig -version} rescue ''
  swig_version = swig_version.scan(/swig version 3.0.\d*/i)
  if swig_version.empty?
    $stderr.puts '== ERROR ================================================================='
    $stderr.puts "Could not find required swig version 3.0.*, found #{swig_version.inspect}"
    $stderr.puts 'Please install swig "~ 3.0.8" and try again.'
    $stderr.puts '=========================================================================='
    raise
  end

  # The c-lib version is different from the gem version
  oboe_version = ENV['OBOE_VERSION'] || 'latest'
  oboe_s3_dir = "https://s3-us-west-2.amazonaws.com/rc-files-t2/c-lib/#{oboe_version}"
  ext_src_dir = File.expand_path('ext/oboe_metal/src')

  # VERSION is used by extconf.rb to download the correct liboboe when installing the gem
  remote_file = File.join(oboe_s3_dir, 'VERSION')
  local_file = File.join(ext_src_dir, 'VERSION')
  puts "fetching #{remote_file} to #{local_file}"
  open(remote_file, 'rb') do |rf|
    content = rf.read
    File.open(local_file, 'wb') { |f| f.puts content }
  end

  # oboe and bson header files
  FileUtils.mkdir_p(File.join(ext_src_dir, 'bson'))
  %w(oboe.h oboe.hpp oboe_debug.h oboe.i bson/bson.h bson/platform_hacks.h).each do |filename|
    remote_file = File.join(oboe_s3_dir, 'include', filename)
    local_file = File.join(ext_src_dir, filename)

    puts "fetching #{remote_file} to #{local_file}"
    open(remote_file, 'rb') do |rf|
      content = rf.read
      File.open(local_file, 'wb') { |f| f.puts content }
    end
  end

  FileUtils.cd(ext_src_dir) do
    system('swig -c++ -ruby -module oboe_metal oboe.i')
    FileUtils.rm('oboe.i')
  end
end

desc "Build the gem's c extension"
task :compile do
  if !defined?(JRUBY_VERSION)
    puts "== Building the c extension against Ruby #{RUBY_VERSION}"

    pwd      = Dir.pwd
    ext_dir  = File.expand_path('ext/oboe_metal')
    final_so = File.expand_path('lib/oboe_metal.so')
    so_file  = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    ENV['APPOPTICS_FROM_S3'] = 'true'
    cmd = [Gem.ruby, 'extconf.rb']
    sh cmd.join(' ')
    sh '/usr/bin/env make'

    File.delete(final_so) if File.exist?(final_so)

    if File.exist?(so_file)
      FileUtils.mv(so_file, final_so)
      Dir.chdir(pwd)
      puts "== Extension built and moved to #{final_so}"
    else
      Dir.chdir(pwd)
      puts '!! Extension failed to build (see above). Have the required binary and header files been fetched?'
      puts '!! Try the tasks in this order: clean > fetchsource > compile.'
    end
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc 'Clean up extension build files'
task :clean do
  if !defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    symlinks = [
      File.expand_path('lib/oboe_metal.so'),
      File.expand_path('ext/oboe_metal/lib/liboboe.so'),
      File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
    ]

    symlinks.each do |symlink|
      FileUtils.rm_f symlink
    end
    Dir.chdir ext_dir
    sh '/usr/bin/env make clean' if File.exist? 'Makefile'

    Dir.chdir pwd
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc 'Remove all built files and extensions'
task :distclean do
  if !defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')
    symlinks = [
      File.expand_path('lib/oboe_metal.so'),
      File.expand_path('ext/oboe_metal/lib/liboboe.so'),
      File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
    ]

    if File.exist? mkmf_log
      symlinks.each do |symlink|
        FileUtils.rm_f symlink
      end
      Dir.chdir ext_dir
      sh '/usr/bin/env make distclean' if File.exist? 'Makefile'

      Dir.chdir pwd
    else
      puts 'Nothing to distclean. (nothing built yet?)'
    end
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc "Rebuild the gem's c extension"
task :recompile => [:distclean, :compile]

task :environment do
  ENV['APPOPTICS_GEM_VERBOSE'] = 'true'

  Bundler.require(:default, :development)
  AppOpticsAPM::Config[:tracing_mode] = :always
  AppOpticsAPM::Test.load_extras

  if AppOpticsAPM::Test.gemfile?(:delayed_job)
    require 'delayed/tasks'
  end
end

task :console => :environment do
  ARGV.clear
  if AppOpticsAPM::Test.gemfile?(:delayed_job)
    require './test/servers/delayed_job'
  end
  Pry.start
end

# Used when testing Resque locally
task 'resque:setup' => :environment do
  require 'resque/tasks'
end
