#!/usr/bin/env bash

mapfile -t input2 < <(./read_travis_yml.rb)

cd /code/ruby-appoptics

for index in ${!input2[*]} ;
do
  args=(${input2[$index]})
  rbenv local ${args[0]}
  export BUNDLE_GEMFILE=${args[1]}
  export ${args[2]}

  echo "Installing gems ..."
  bundle install --quiet

  if [ "$?" -eq 0 ]; then
    rm -f /tmp/appoptics_traces.bson
    bundle exec rake test
    if [ "$?" -ne 0 ]; then exit 1; fi
    pids=`ps -ef | grep 'sidekiq' | grep -v grep | awk '{print $2}'`
    if [ "$pids" != "" ]; then
      ps -ef | grep 'sidekiq' | grep -v grep | awk '{print $2}' | xargs kill
    fi
  else
    echo "Problem installing gems. Skipping tests for $*"
    exit 1
  fi
done

cd -