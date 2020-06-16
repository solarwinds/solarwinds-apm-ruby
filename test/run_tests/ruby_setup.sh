#!/bin/bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

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

rm -f Gemfile.lock
rm -f gemfiles/*.lock
#rm -f .ruby-version

#rbenv global 2.5.5
#
#echo "Installing gems ..."
#bundle install # --quiet
#
#bundle exec rake clean fetch compile

echo "Starting services ..."
## start postgres
# runs in its own container now
#service postgresql start

## start redis with password
redis-server --requirepass secret_pass &

## start memcached
# starting it as service in docker is tricky for centos/alpine
if [[ $(getent passwd memcached) = "" ]]; then
  /usr/bin/memcached -m 64 -p 11211 -u memcache &
else
  /usr/bin/memcached -m 64 -p 11211 -u memcached &
fi
#service memcached start

## add table for tests in mysql
# sorry for the warning about providing the password on the commandline
# changed to using init.sql
#
# mysql -e 'create database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD


## we also want to use this file to setup the env without running the tests
# if we run the tests we make a copy of the tiles so that they can be edited
# without influencing the test run
if [ "$1" == "test" ]; then
  echo "Running tests ..."
  cd test/run_tests
  ./run_tests.sh -c
else
  /bin/bash
fi

cd $dir
# mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD
