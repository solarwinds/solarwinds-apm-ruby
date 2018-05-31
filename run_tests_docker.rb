#!/usr/bin/env ruby

# this runs all the tests on the current code base
# any edits take effect immediately
# test output is logged to log/test_runs.log
# make sure log/ and log/test_runs.log is writeable by docker

# `docker build -f Dockerfile_test -t ruby_appoptics_apm .`
# (docker-compose will build it too if missing)

require 'yaml'
travis = YAML.load_file('.travis.yml')

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

matrix.each do |args|
  `docker-compose run --rm --service-ports ruby_appoptics_apm /code/ruby-appoptics_apm/ruby_setup.sh #{args['rvm']} #{args['gemfile']} #{args['env']}`
  puts "docker-compose run --rm --service-ports ruby_appoptics_apm /code/ruby-appoptics_apm/ruby_setup.sh #{args['rvm']} #{args['gemfile']} #{args['env']}"
end
