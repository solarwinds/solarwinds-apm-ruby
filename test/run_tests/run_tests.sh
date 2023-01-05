#!/usr/bin/env bash

# Copyright (c) SolarWinds, LLC.
# All rights reserved.

##
# This script can be used to run all or select tests in a Linux environment with
# the solarwinds_apm dependencies already installed
# This is usually achieved by a combination of:
# - the setup of the docker image and
# - running the ruby_setup.sh script
#
# This script offers the following options:
# -r ruby-version   - restrict the tests to run with this ruby version
# -g gemfile        - restrict the tests to the ones associated with this gemfile (path from gem-root)
# -d database type  - restrict to one of 'mysql' or 'postgresql' for rails tests
# -p prepared statements - 0 or 1 to enable/disable prepared statements in rails
# -c copy           - run tests with a copy of the code, so that edits don't interfere
#
# Rails 7 tests run only with Ruby >= 2.7.x
# Rails 5 tests run only with Ruby <= 2.5.x
#
# Because of github actions this script is set up to be run from the
# gem root directory
#
# Caveat: The runs cannot or only partially be interrupted with control-c
#         It is faster to use kill from a different shell
##

##
# Set up the default rubies, gemfiles and database types
#
# !!! When changing or adding ruby versions, the versions have to be
# updated in the docker images as well, locally and in github !!!
##
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
  "gemfiles/redis.gemfile"
# "gemfiles/profiling.gemfile"
)

dbtypes=("mysql" "postgresql")
prep_stmts=(0 1)

# TODO think about storing and resetting after the tests:
#  - BUNDLE_GEMFILE in the env (there may be none)
#  - the current ruby version (which is tricky, because it may not have been set by rbenv)

dir=$(pwd)
# the following is sometimes needed when there are new gem versions with
# dependency conflicts
# export BUNDLE_ALLOW_BUNDLER_DEPENDENCY_CONFLICTS=true

exit_status=-1

##
# Read opts
##
copy=0
while getopts ":r:g:d:p:n:c:" opt; do
  case ${opt} in
    r ) # process option a
      rubies=($OPTARG)
      ;;
    g ) # process option t
      gemfiles=($OPTARG)
      ;;
    d )
      dbtypes=($OPTARG)
      ;;
    p )
      if ! [[ $OPTARG =~ ^[01]$ ]] ; then
        echo "Error: prepared statements option must be 0 or 1"
        exit 1
      else
        prep_stmts=($OPTARG)
      fi
      ;;
    c )
      copy=1
      ;;
    \? ) echo "
Usage: $0 [-r ruby-version] [-g gemfile] [-d database type] [-p prepared_statements] [-c copy files]

     -r ruby-version        - restrict the tests to run with this ruby version
     -g gemfile             - restrict the tests to the ones associated with this gemfile (path from gem-root)
     -d database type       - restrict to restrict to one of 'mysql' or 'postgresql' for rails tests
     -p prepared statements - 0 or 1 to enable/disable prepared statements in rails
     -c copy                - run tests with a copy of the code, so that edits don't interfere

Rails 7 tests run with Ruby >= 2.7.x
Rails 5 tests run with Ruby <= 2.5.x
"
      exit 1
      ;;
  esac
done

##
# setup files and env vars
##
if [ "$copy" -eq 1 ]; then
    rm -rf /tmp/ruby-solarwinds_test
    cp -r . /tmp/ruby-solarwinds_test

    cd /tmp/ruby-solarwinds_test/ || exit 1
fi
rm -f gemfiles/*.lock

time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="log/testrun_"$time".log"
echo "logfile name: $TEST_RUNS_FILE_NAME"

##
# loop through rubies, gemfiles, and database types to
# set up and run tests
##
for ruby in ${rubies[@]} ; do
  rbenv local $ruby
  # TODO this patching should be moved to ruby_setup.sh
  # if this is running on alpine and using ruby 3++, we need to patch
  if [[ -r /etc/alpine-release ]]; then
    if [[ $ruby =~ ^3.0.* ]]; then
      # download and apply patch, may fail if it has already been applied, that's ok
      cd /root/.rbenv/versions/$ruby/include/ruby-3.0.0/ruby/internal/ || exit 1
      curl -sL https://bugs.ruby-lang.org/attachments/download/8821/ruby-ruby_nonempty_memcpy-musl-cxx.patch -o memory.patch
      patch -N memory.h memory.patch
      cd - || exit 1
    elif [[ $ruby =~ ^3.1.* ]]; then
      # download and apply patch, may fail if it has already been applied, that's ok
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
    echo "Current test status: $exit_status (after ext compiling)"
    continue
  fi

  for gemfile in ${gemfiles[@]} ; do
    export BUNDLE_GEMFILE=$gemfile

    # ignore redis test for regular push event
    # if [[ $gemfile =~ .*redis.* && $PUSH_EVENT =~ .*REGULAR_PUSH.* ]]; then continue; fi

    # don't run rails 5 with Ruby >= 3
    if [[ $gemfile =~ .*rails5.* && $ruby =~ ^3.* ]]; then continue; fi

    # don't run rails 7 with Ruby <= 2.6
    if [[ $gemfile =~ .*rails7.* && $ruby =~ ^2.[65].* ]]; then continue; fi

    echo "*** installing gems from $BUNDLE_GEMFILE ***"

    export ARCH=$(uname -m)
    if [[ $ARCH == "arm64" || $ARCH == "aarch64" ]]; then
      bundle config set force_ruby_platform true
    fi

    bundle update # --quiet
    if [ "$?" -ne 0 ]; then
      echo "Problem during gem install. Skipping tests for $gemfile"
      exit_status=1
      echo "Current test status: $exit_status (after bundle update)"
      continue
    fi

    # run only the rails tests with all databases
    if [[ $gemfile =~ .*rails.* ]] ; then
      dbs=(${dbtypes[*]})
      preps=(${prep_stmts[*]})
    else
      dbs=(${dbtypes[0]})
      preps=(${prep_stmts[0]})
    fi

    for dbtype in ${dbs[@]} ; do
      echo "Current database type $dbtype"
      export DBTYPE=$dbtype

      for prep_stmt in ${preps[@]} ; do
#        echo "Using prepared statements: $prep_stmt"
        if [ $prep_stmt = '0' ]; then
          export TEST_PREPARED_STATEMENT=false
        elif [ $prep_stmt = '1' ]; then
          export TEST_PREPARED_STATEMENT=true
        fi

        # and here we are finally running the tests!!!
        
        bundle exec rake test --trace
        status=$?
        retries=0
        while [ $status -ne 0 ] && [ $retries -ne 1 ]
        do
          sleep 10
          retries=$(( $retries + 1 ))
          echo "Retried in $retries times"
          bundle exec rake test --trace
          status=$?
        done

        [[ $status -ne 0 ]] && echo "!!! Test suite failed for $gemfile with Ruby $ruby !!!"
        [[ $status -gt $exit_status ]] && exit_status=$status
        echo "Current test status: $status (status - after bundle exec rake test)"
        echo "Current test status: $exit_status (exit_status - after bundle exec rake test)"

        pkill -f sidekiq
      done
    done
  done
done

echo ""
echo "--- SUMMARY of $TEST_RUNS_FILE_NAME ------------------------------"
grep -E '===|failures|FAIL|ERROR' "$TEST_RUNS_FILE_NAME"

echo "Check if there is any failures"
TESTCASE_FAILED=$(awk '/[^0] failures, /' $TEST_RUNS_FILE_NAME)
# [[ "$TESTCASE_FAILED" != "" ]] && exit_status=1
echo "TESTCASE_FAILED is $TESTCASE_FAILED"
echo "Current test status: $exit_status (after check if there is any failures)"

echo "Check if there is any errors"
TESTCASE_ERROR=$(awk '/failures, [^0] errors, /' $TEST_RUNS_FILE_NAME)
# [[ "$TESTCASE_ERROR" != "" ]] && exit_status=1
echo "TESTCASE_FAILED is $TESTCASE_ERROR"
echo "Current test status: $exit_status (after check if there is any errors)"

echo "Current test status: $exit_status"

if [ "$copy" -eq 1 ]; then
  mv "$TEST_RUNS_FILE_NAME" "$dir"/log/
fi

exit $exit_status

