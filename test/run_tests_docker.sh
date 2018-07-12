#!/usr/bin/env bash

cd "$( dirname "$0" )"/run_tests
docker-compose run --service-ports ruby_appoptics /code/ruby-appoptics/test/run_tests/ruby_setup.sh test
cd -