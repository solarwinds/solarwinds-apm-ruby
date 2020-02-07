#!/bin/bash

if [[ $BUNDLE_GEMFILE == *"gemfiles/frameworks.gemfile"* ]]
then
  gem install bundler -v 1.17.3
  bundle _1.17.3_ update --jobs=3 --retry=3
else
  bundle update --jobs=3 --retry=3
fi
