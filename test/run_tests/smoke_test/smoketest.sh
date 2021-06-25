#!/usr/bin/env bash

# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved.

path=$(dirname "$0")

# assuming APPOPTICS_SERVICE_KEY is set
export APPOPTICS_COLLECTOR=collector-stg.appoptics.com
unset APPOPTICS_REPORTER
unset APPOPTICS_FROM_S3
unset OBOE_WIP

# bundler has a problem resolving the gem in packagecloud
# when defining the gemfile via BUNDLE_GEMFILE
# therefore there is a step to clean the gems between runs

for version in 3.0.1 2.7.3 2.6.7 2.5.8 2.4.10
do
  printf "\n=== $version ===\n"
  rbenv local $version

  export BUNDLE_GEMFILE=$path/Gemfile_clean
  rm -f $path/GemFile_clean.lock
  bundle
  bundle clean --force

  export BUNDLE_GEMFILE=$path/Gemfile
  rm -f $path/GemFile.lock
  bundle update

  bundle exec ruby $path/make_traces.rb

done

unset BUNDLE_GEMFILE
