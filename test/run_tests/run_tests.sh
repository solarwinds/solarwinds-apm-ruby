#!/usr/bin/env bash

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

export BUNDLE_ALLOW_BUNDLER_DEPENDENCY_CONFLICTS=true
RUBY=`rbenv local`
## Read opts
num=-1
while getopts ":r:g:e:n:" opt; do
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
    \? ) echo "
Usage: $0 [-r ruby-version] [-g gemfile] [-e env-setting] [-n num-tests]

     -r ruby-version - restrict the tests to run with this ruby version
     -g gemfile      - restrict the tests to the ones associated with this gemfile (path from gem-root)
     -e env-setting  - restrict to this env setting, eg DBTYPE=postgresql
     -n num          - run only the first num tests, -n1 is useful when debugging

The values for -r, -g, and -e have to correspond to configurations in the .travis.yml file
"
      exit 1
      ;;
  esac
done

## Read travis configuration
cd "$( dirname "$0" )/../.."
mapfile -t input2 < <(test/run_tests/read_travis_yml.rb .travis.yml)

## Setup and run tests
for index in ${!input2[*]} ;
do
  args=(${input2[$index]})

  if [[ "$ruby" != "" && "$ruby" != "${args[0]}" ]]; then continue; fi
  rbenv local ${args[0]}

  if [[ "$gemfile" != "" && "$gemfile" != "${args[1]}" ]]; then continue; fi
  export BUNDLE_GEMFILE=${args[1]}
  echo ${args[1]}.lock
  rm -f ${args[1]}.lock

  if [[ "$env" != "" && "$env" != "${args[2]}" ]]; then continue; fi
  export ${args[2]}

  echo
  echo "Installing gems ... for $(ruby -v)"
  bundle update --quiet

  if [ "$?" -eq 0 ]; then
    bundle exec rake test

    # kill all sidekiq processes, they don't stop automatically and can add up if tests are run repeatedly
    pids=`ps -ef | grep 'sidekiq' | grep -v grep | awk '{print $2}'`
    if [ "$pids" != "" ]; then kill $pids; fi
  else
    echo "Problem during gem install. Skipping tests for ${args[1]}"
    rbenv local 2.5.5
    exit 1 # we are not continuing here to keep ctrl-c working as expected
  fi

  num=$((num-1))
  if [ "$num" -eq "0" ]; then
    rbenv local 2.5.5
    cd -
    exit
  fi
done

rbenv local $RUBY
cd -
