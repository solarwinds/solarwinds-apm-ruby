#!/usr/bin/env bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

##
# This script can be used to run all or select tests in a Linux environment with
# the appoptics_apm dependencies installed
#
# It offers the following options:
# -r ruby-version - restrict the tests to run with this ruby version
# -g gemfile      - restrict the tests to the ones associated with this gemfile (path from gem-root)
# -e env-setting  - restrict to this env setting, eg DBTYPE=postgresql
# -n num          - run only the first num tests, -n1 is useful when debugging
#
# The options for -r, -g, and -e have to correspond to configurations in the travis.yml file
##
dir=`pwd`
export BUNDLE_ALLOW_BUNDLER_DEPENDENCY_CONFLICTS=true
export OBOE_WIP=true
# RUBY=`rbenv local`

## Read opts
num=-1
copy=0
while getopts ":r:g:e:n:c:" opt; do
  case ${opt} in
    r ) # process option a
      ruby=$OPTARG
      ;;
    g ) # process option t
      gemfile=$OPTARG
      export BUNDLE_GEMFILE=$gemfile
      ;;
    e )
      env=$OPTARG
      ;;
    n )
      num=$OPTARG
      ;;
    c )
      copy=1
      ;;
    \? ) echo "
Usage: $0 [-r ruby-version] [-g gemfile] [-e env-setting] [-n num-tests]

     -r ruby-version - restrict the tests to run with this ruby version
     -g gemfile      - restrict the tests to the ones associated with this gemfile (path from gem-root)
     -e env-setting  - restrict to this env setting, eg DBTYPE=postgresql
     -n num          - run only the first num tests, -n1 is useful when debugging
     -c copy         - run tests with a copy of the code, so that edits don't interfere

The values for -r, -g, and -e have to correspond to configurations in the .travis.yml file
"
      exit 1
      ;;
  esac
done

cd /code/ruby-appoptics

# version=`rbenv version`
# set -- $version
# RUBY=$1
if [ "$copy" -eq 1 ]; then
    rm -rf /code/ruby-appoptics_test
    cp -r /code/ruby-appoptics /code/ruby-appoptics_test

    cd /code/ruby-appoptics_test/
fi

## Read travis configuration
mapfile -t input2 < <(test/run_tests/read_travis_yml.rb .travis.yml)
current_ruby=""

time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="log/testrun_"$time".log"

echo $TEST_RUNS_FILE_NAME

## Setup and run tests
for index in ${!input2[*]} ;
do
  args=(${input2[$index]})

  if [[ "$gemfile" != "" && "$gemfile" != "${args[1]}" ]]; then continue; fi
  export BUNDLE_GEMFILE=${args[1]}
#   echo ${args[1]}.lock
  rm -f ${args[1]}.lock

  if [[ "$env" != "" && "$env" != "${args[2]}" ]]; then continue; fi
  export ${args[2]}

  if [[ "$ruby" != "" && "$ruby" != "${args[0]}" ]]; then continue; fi
  if [[ "${args[0]}" != $current_ruby ]]; then
    rbenv local ${args[0]}
    current_ruby=${args[0]}
    echo
    echo "Installing gems ... for $(ruby -v)"
    if [[ "$BUNDLE_GEMFILE" == *"gemfiles/frameworks.gemfile"* || "$BUNDLE_GEMFILE" == *"gemfiles/rails42.gemfile"* ]]
    then
      echo "*** using bundler 1.17.3 with $BUNDLE_GEMFILE ***"
      bundle _1.17.3_ update # --quiet
    else
      echo "*** using default bundler with $BUNDLE_GEMFILE ***"
      bundle update # --quiet
    fi
    bundle exec rake clean fetch compile
  else
    echo
    echo "Installing gems ... for $(ruby -v)"
    if [[ "$BUNDLE_GEMFILE" == *"gemfiles/frameworks.gemfile"* || "$BUNDLE_GEMFILE" == *"gemfiles/rails42.gemfile"* ]]
    then
      echo "*** using bundler 1.17.3 with $BUNDLE_GEMFILE ***"
      bundle _1.17.3_ update # --quiet
    else
      echo "*** using default bundler with $BUNDLE_GEMFILE ***"
      bundle update # --quiet
    fi
  fi

  if [ "$?" -eq 0 ]; then
    bundle exec rake test

    # kill all sidekiq processes, they don't stop automatically and can add up if tests are run repeatedly
    pids=`ps -ef | grep 'sidekiq' | grep -v grep | awk '{print $2}'`
    if [ "$pids" != "" ]; then kill $pids; fi
  else
    echo "Problem during gem install. Skipping tests for ${args[1]}"
    rbenv local  2.5.8
    exit 1 # we are not continuing here to keep ctrl-c working as expected
  fi

  num=$((num-1))
  if [ "$num" -eq 0 ]; then
    rbenv local 2.5.8
    cd $dir
    exit
  fi
done

echo ""
echo "--- SUMMARY ------------------------------"
egrep '===|failures|FAIL|ERROR' $TEST_RUNS_FILE_NAME

if [ "$copy" -eq 1 ]; then
    mv $TEST_RUNS_FILE_NAME /code/ruby-appoptics/log/
fi

rbenv local $RUBY
cd $dir
