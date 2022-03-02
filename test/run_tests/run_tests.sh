#!/usr/bin/env bash

# Copyright (c) SolarWinds, LLC.
# All rights reserved.

##
# This script can be used to run all or select tests in a Linux environment with
# the appoptics_apm dependencies already installed
# This is usually achieved by a combination of:
# - the setup of the docker image and
# - running the ruby_setup.sh script
#
# This script offers the following options:
# -r ruby-version   - restrict the tests to run with this ruby version
# -g gemfile        - restrict the tests to the ones associated with this gemfile (path from gem-root)
# -d database type  - restrict to one of 'mysql2' or 'postgresql' for rails tests
# -n num            - run only the first num tests, -n1 is useful for debugging a new test setup
# Rails 7 tests run only with Ruby >= 2.7.x
# Rails 5 tests run only with Ruby <= 2.5.x
#
# Because of github actions this script is set up to be run from the
# gem root directory
#
# Caveat: The runs cannot or only partially be interrupted with control-c
##

##
# Setting up the default rubies, gemfiles and database types
#
# !!! When changing or adding ruby versions, the versions have to be
# updated in the docker images as well, locally and in github !!!
rubies=("3.1.0" "3.0.3" "2.7.5" "2.6.9" "2.5.9")

gemfiles=(
  "gemfiles/libraries.gemfile"
  "gemfiles/unit.gemfile"
  "gemfiles/instrumentation_mocked.gemfile"
  "gemfiles/instrumentation_mocked_oldgems.gemfile"
  "gemfiles/frameworks.gemfile"
  "gemfiles/rails70.gemfile"
  "gemfiles/rails61.gemfile"
  "gemfiles/rails52.gemfile"
  "gemfiles/delayed_job.gemfile"
  "gemfiles/noop.gemfile"
# 'gemfiles/profiling.gemfile"
)

dbtypes=("mysql2" "postgresql")

# TODO think about storing and resetting after the tests:
#  - BUNDLE_GEMFILE in the env
#  - the current ruby version (which is tricky, because it may not have been set by rbenv)

dir=$(pwd)
# export BUNDLE_ALLOW_BUNDLER_DEPENDENCY_CONFLICTS=true

exit_status=-1

## Read opts
num=-1
copy=0
while getopts ":r:g:d:n:c:" opt; do
  case ${opt} in
    r ) # process option a
      rubies=($OPTARG)
      ;;
    g ) # process option t
      gemfiles=($OPTARG)
      ;;
    d )
      env=($OPTARG)
      ;;
    n )
      num=$OPTARG
      ;;
    c )
      copy=1
      ;;
    \? ) echo "
Usage: $0 [-r ruby-version] [-g gemfile] [-d database type] [-n num-tests]

     -r ruby-version   - restrict the tests to run with this ruby version
     -g gemfile        - restrict the tests to the ones associated with this gemfile (path from gem-root)
     -d database type  - restrict to either 'mysql2' or 'postgresql' for rails tests
     -n num            - run only the first num tests, -n1 is useful when debugging
     -c copy           - run tests with a copy of the code, so that edits don't interfere

Rails 7 tests run with Ruby >= 2.7.x
Rails 5 tests run with Ruby <= 2.5.x
"
      exit 1
      ;;
  esac
done



if [ "$copy" -eq 1 ]; then
    rm -rf /tmp/ruby-appoptics_test
    cp -r . /tmp/ruby-appoptics_test

    cd /tmp/ruby-appoptics_test/ || exit 1
fi

time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="log/testrun_"$time".log"
echo "logfile name: $TEST_RUNS_FILE_NAME"

# loop through rubies, gemfiles, and database types to
# set up and run tests
for ruby in ${rubies[@]} ; do
  rbenv local $ruby
  # if this is running on alpine and using ruby 3++, we need to patch
  if [[ -r /etc/alpine-release ]]; then
    if [[ $ruby =~ ^3.0.* ]]; then
      # download and apply patch
      cd /root/.rbenv/versions/$ruby/include/ruby-3.0.0/ruby/internal/ || exit 1
      curl -sL https://bugs.ruby-lang.org/attachments/download/8821/ruby-ruby_nonempty_memcpy-musl-cxx.patch -o memory.patch
      patch -N memory.h memory.patch
      cd - || exit 1
    elif [[ $ruby =~ ^3.1.* ]]; then
      # download and apply patch
      cd /root/.rbenv/versions/$ruby/include/ruby-3.1.0/ruby/internal/ || exit 1
      curl -sL https://bugs.ruby-lang.org/attachments/download/8821/ruby-ruby_nonempty_memcpy-musl-cxx.patch -o memory.patch
      patch -N memory.h memory.patch
      cd - || exit 1
    fi
  fi
  unset BUNDLE_GEMFILE
  bundle update
  bundle exec rake clean fetch compile

  if [ "$?" -ne 0 ]; then
    echo "Problem while installing c-extension with ruby $ruby"
    exit_status=1
    continue
  fi

  for gemfile in ${gemfiles[@]} ; do
    export BUNDLE_GEMFILE=$gemfile

    # don't run rails 5 with Ruby >= 3
    if [[ $gemfile =~ .*rails5.* && $ruby =~ ^3.* ]]; then continue; fi

    # don't run rails 7 with Ruby <= 2.6
    if [[ $gemfile =~ .*rails7.* && $ruby =~ ^2.[65].* ]]; then continue; fi

    echo "*** installing gems from $BUNDLE_GEMFILE ***"
    bundle update # --quiet
    if [ "$?" -ne 0 ]; then
      echo "Problem during gem install. Skipping tests for $gemfile"
      exit_status=1
      continue
    fi

    # run only the rails tests with all databases
    if [[ $gemfile =~ .*rails.* ]] ; then
      dbs=(${dbtypes[*]})
    else
      dbs=(${dbtypes[0]})
    fi

    for dbtype in ${dbs[@]} ; do
      echo "Current database type $dbtype"
      export DBTYPE=$dbtype

      # and here we are finally running the tests!!!
      bundle exec rake test
      status=$?
      [[ $status -gt $exit_status ]] && exit_status=$status
      [[ $status -ne 0 ]] && echo "!!! Test suite failed for $gemfile with Ruby $ruby !!!"

      # kill all sidekiq processes
      # they don't stop automatically and can add up
      kill -9 $(pgrep -f sidekiq)

      if $num ; then
        num=$((num-1))
        if [ "$num" -eq 0 ]; then
          exit $exit_status
        fi
      fi
    done
  done
done

echo ""
echo "--- SUMMARY ------------------------------"
grep -E '===|failures|FAIL|ERROR' "$TEST_RUNS_FILE_NAME"

if [ "$copy" -eq 1 ]; then
    mv "$TEST_RUNS_FILE_NAME" "$dir"/log/
fi

exit $exit_status