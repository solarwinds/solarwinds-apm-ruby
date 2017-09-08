#!/bin/bash

# call with:
# docker-compose run --service-ports ruby_appoptics /code/ruby-appoptics/ruby_debug.sh <ruby-version> <gemfile>
# docker-compose run --service-ports ruby_appoptics /code/ruby-appoptics/ruby_debug.sh 1.9.3 gemfiles/libraries.gemfile

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

bundle exec rake test TEST=test/queues/test/instrumentation/sidekiq-client_test.rb
/bin/bash

mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD