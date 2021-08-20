#!/bin/bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

##
# This script sets up the environment for running the tests
#
# Many of the tests depend on redis or memcached
# these will be started here
#
# Further necessary services like mysql, rabbitmq, and mongo are setup through docker-compose
##

dir=`pwd`

# Because of github actions we now have to always run this from the
# gem root directory
# cd /code/ruby-appoptics

rm -f Gemfile.lock
rm -f gemfiles/*.lock
#rm -f .ruby-version

#rbenv global 2.5.8
#
#echo "Installing gems ..."
#bundle install # --quiet
#
#bundle exec rake clean fetch compile

echo "Starting services ..."

## Start redis with password

## retry if this doesn't work immediately, `rm dump.rdb`
redis_pass="${REDIS_PASSWORD:-secret_pass}"
redis-server --requirepass $redis_pass --loglevel warning &
attemps=3
while [ $? -ne 0 ]; do
  sleep 1
  echo "retrying redis-server start up"
  redis-server --requirepass $redis_pass &
  attemps=$attemps-1
  if [[ $attemps -eq 0 ]]; then
    echo "couldn't start redis"
    exit 1
  fi
done

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
  if [ "$2" == "copy" ]; then
    test/run_tests/run_tests.sh -c
  else
    test/run_tests/run_tests.sh
  fi
else
  /bin/bash
fi

# mysql -e 'drop database travis_ci_test;' -h$MYSQL_HOST -p$MYSQL_ROOT_PASSWORD
cd $dir
