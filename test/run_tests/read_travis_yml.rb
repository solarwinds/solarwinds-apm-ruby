#!/usr/bin/env ruby

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

##
# This script reads the travis.yml file and provides the arguments for the jobs to run
# It was written to produce input to the bash script that runs the tests
#
# The tests can't be run from this file, because it is not possible to switch ruby versions
# while executing a ruby script
#
# output format:
# ruby-version gemfile env-setting\n
##

if ARGV.count != 1
  $stderr.puts "Usage: #{File.basename __FILE__} <path-to-travis-yml>"
  $stderr.puts "       <path-to-travis-yml> filename of the travis file from which to generate the list of tests to run"
  exit 1
end

require 'yaml'
travis = YAML.load_file(ARGV[0])

# create the travis build matrix
matrix = []
travis['rvm'].each do |rvm|
  unless rvm == 'ruby-head'
    travis['gemfile'].each do |gemfile|
      travis['env'].each do |env|
        matrix << { "rvm" => rvm, "gemfile" => gemfile, 'env' => env}
      end
    end
  end
end

# delete excluded permutations
travis['matrix']['exclude'].each do |h|
  matrix.delete_if { |m| m == m.merge(h) }
end

matrix.each do |args|
  puts "#{args['rvm']} #{args['gemfile']} #{args['env']}\n"
end
