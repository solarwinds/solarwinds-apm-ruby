#!/bin/bash

# Copyright (c) SolarWinds, LLC.
# All rights reserved.

##
# This script sets up the environment for running the tests
#
# Many of the tests depend on redis or memcached
# these will be started here
#
# Further necessary services like mysql, rabbitmq, and mongo are setup through docker-compose
##

# !!! Because of github actions we now have to always run this script from the
# gem root directory !!!

rm -f Gemfile.lock
rm -f gemfiles/*.lock

echo "Starting services ..."

## Start redis with password

## 2 retries if this doesn't work immediately
# sometimes `rm dump.rdb` helps
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
# ideally we would start it as service,
# but it is tricky for centos/alpine docker containers
if [[ $(getent passwd memcached) = "" ]]; then
  /usr/bin/memcached -m 64 -p 11211 -u memcache &
else
  /usr/bin/memcached -m 64 -p 11211 -u memcached &
fi

## we also want to use this file to setup the env for running
# single test files or individual tests
#
# if we run in `test` mode there is an option make a copy of the files
# so the original can be edited without influencing the test run
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
