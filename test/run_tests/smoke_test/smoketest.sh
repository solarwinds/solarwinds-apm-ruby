#!/usr/bin/env bash

path=$(dirname "$0")

export APPOPTICS_COLLECTOR=collector-stg.appoptics.com
export BUNDLE_GEMFILE=$path/GemFile
unset APPOPTICS_REPORTER

rm -f $path/GemFile.lock
bundle update
bundle exec ruby $path/make_traces.rb
