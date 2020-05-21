#!/usr/bin/env bash

path=$(dirname "$0")

export APPOPTICS_COLLECTOR=collector-stg.appoptics.com
unset APPOPTICS_REPORTER

# bundler has a problem resolving the gem in packagecloud
# when defining the gemfile via BUNDLE_GEMFILE
#export BUNDLE_GEMFILE=$path/Gemfile

rm -f $path/GemFile.lock
bundle update --gemfile=$path/Gemfile

bundle exec ruby $path/make_traces.rb
