#!/usr/bin/env ruby

# this runs all the tests on the current code base
# any edits take effect immediately
# test output is logged to log/test_runs.log
# make sure log/ and log/test_runs.log is writeable by docker

# `docker build -f Dockerfile_test -t ruby_appoptics_apm .`
# (docker-compose will build it too if missing)

# if ARGV.count != 1
#   $stderr.puts "Usage: #{File.basename __FILE__} <out_filename>"
#   $stderr.puts "       <out_filename> filename for the list of tests to run"
#   exit 1
# end
#
# script = ARGV[0]

require 'yaml'
travis = YAML.load_file('../../.travis.yml')

matrix = []
travis['rvm'].each do |rvm|
  travis['gemfile'].each do |gemfile|
    travis['env'].each do |env|
      matrix << { "rvm" => rvm, "gemfile" => gemfile, 'env' => env}
    end
  end
end

travis['matrix']['exclude'].each do |h|
  matrix.delete_if do |m|
    m == m.merge(h)
  end
end

# File.open(script, 'w') do |f|
#   f.write("#!/usr/bin/env bash\n\n")
  # Tests need to run in a different shell, so that we can switch the ruby version
  matrix.each do |args|
    puts "#{args['rvm']} #{args['gemfile']} #{args['env']}\n"
    # f.write("./run_test.sh #{args['rvm']} #{args['gemfile']} #{args['env']}\n")
    # system("./run_test.sh #{args['rvm']} #{args['gemfile']} #{args['env']}")
    # `./run_test.sh #{args['rvm']} #{args['gemfile']} #{args['env']}`
  end
# end

# `chmod +x #{script}`


