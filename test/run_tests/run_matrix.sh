#!/bin/bash

##
# This script can be used to run one test file against multiple ruby and
# gem versions
#
# The versions need to be set within this file

RUBY=`rbenv global`
export RUBY_ENV=test

read -r -d '' gemfile_string << EOM
source 'https://rubygems.org'

group :development, :test do
  gem 'bson'
  gem 'minitest'
  gem 'minitest-reporters', '1.3.0' # 1.3.1 is breaking tests
  gem 'minitest-debugger', :require => false
  gem 'minitest-hooks'
  gem 'mocha'
  gem 'rack-test'
  gem 'rake'
  gem 'puma' # , '< 3.1.0'
  gem 'webmock'
  gem 'grpc-tools' if RUBY_VERSION < '2.7.0'
end
EOM

## specific gem and versions
test_gem="graphql"
test_file_path="test/instrumentation/graphql_test.rb"
#declare -a test_gem_versions=("1.27.0" "1.20.0" "1.13.0" "1.6.0")
declare -a test_gem_versions=("1.7.4" "1.7.7" "1.7.14" "1.8.0" "1.8.17" "1.9.0" "1.9.19" "1.10.0" "1.10.1" "1.10.2")

## ruby versions
declare -a ruby_versions=("2.7.0" "2.6.4" "2.5.5" "2.4.5")
#declare -a ruby_versions=("2.7.0")

## Setup and run tests
for i in "${test_gem_versions[@]}"
do
   gemfile="$test_gem-$i.gemfile"
   export BUNDLE_GEMFILE=$gemfile

   echo "$gemfile_string" > $gemfile
   echo -e "gem '$test_gem', '$i'\n" >> $gemfile
   echo -e "gemspec\n"  >> $gemfile

   for j in "${ruby_versions[@]}"
   do
     rbenv global $j
     bundle update --bundler
     bundle install
     bundle exec rake recompile
     bundle exec ruby -Itest $test_file_path
     rm *.lock
   done
   rm $gemfile
done

rbenv global $RUBY
