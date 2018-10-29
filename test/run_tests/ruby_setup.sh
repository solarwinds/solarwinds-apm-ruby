#!/bin/bash

##
# This script sets up the environment for running the tests
#
# Many of the tests depend on other services like postgres, redis, memcached,
# which will be started here.
#
# Further necessary services like mysql, rabbitmq, and mongo are setup through docker-compose
##

dir=`pwd`
cd /code/ruby-appoptics/

rm -f gemfiles/*.lock
rm -f .ruby-version

rbenv global 2.4.5

echo "Installing gems ..."
bundle install --quiet

bundle exec rake fetch_ext_deps
bundle exec rake clean
bundle exec rake compile

echo "Starting services ..."
## start postgres
service postgresql start

## start redis with password
redis-server --requirepass secret_pass &

## start memcached
service memcached start

## add table for tests in mysql
# sorry for the warning about providing the password on the commandline
mysql -e 'create database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD

## we also want to use this file to setup the env without running all the tests
if [ "$1" == "test" ]; then
  echo "Running tests ..."
  cd test/run_tests
  ./run_tests.sh
else
  /bin/bash
fi

cd $dir
mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD
