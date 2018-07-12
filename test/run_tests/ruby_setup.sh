#!/bin/bash

dir=`pwd`
cd /code/ruby-appoptics/

rm -f .ruby-version

rbenv global 2.4.4

rm -f gemfiles/*.lock

#export RVM_TEST=$1
#export BUNDLE_GEMFILE=$2
bundle install --quiet

bundle exec rake fetch_ext_deps
bundle exec rake clean
bundle exec rake compile

# start postgres
service postgresql start

# start redis with password
redis-server --requirepass secret_pass &

# start memcached
service memcached start

# mysql add table for tests
mysql -e 'create database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD

if [ "$1" == "test" ]; then
  cd test/run_tests
  ./run_tests.sh
else
  /bin/bash
fi

cd $pwd

mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD
