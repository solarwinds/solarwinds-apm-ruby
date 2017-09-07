#!/bin/bash

# call with:
# docker run -it -v `pwd`:/code/ruby-appoptics rubydev /code/ruby-appoptics/ruby_setup.sh <ruby-version> <gemfile_path>
# e.g: docker run -it -v `pwd`:/code/ruby-appoptics rubydev /code/ruby-appoptics/ruby_setup.sh 2.3.1 gemfiles/rails32.gemfile
# use the -d (detached mode) flag to run tests in the background

cd /code/ruby-appoptics/

rbenv local $1
bundle install
bundle exec rake fetch_ext_deps
bundle exec rake clean
bundle exec rake compile

# start postgres
service postgresql start

# start redis
service redis-server start

# start memcached
service memcached start

# mysql add table for tests
mysql -e 'create database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD

bundle install --gemfile $2

export RVM_TEST=$1
export BUNDLE_GEMFILE=$2

#bundle exec rake test
bundle exec rake test TEST=test/queues/delayed_job-client_test.rb
/bin/bash

#mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD