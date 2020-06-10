#!/usr/bin/env bash

path=$(dirname "$0")

export APPOPTICS_COLLECTOR=collector-stg.appoptics.com
unset APPOPTICS_REPORTER
unset APPOPTICS_FROM_S3

# bundler has a problem resolving the gem in packagecloud
# when defining the gemfile via BUNDLE_GEMFILE
# export BUNDLE_GEMFILE=$path/Gemfile

for version in 2.7.0 2.6.4 2.5.5 2.4.5
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
