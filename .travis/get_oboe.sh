#!/bin/bash

set -e # (exit immediatly on failure)
source ~/.profile
# store current ruby
CURRENT_RUBY=`rvm current`
CURRENT_GEMFILE=$BUNDLE_GEMFILE
# set ruby to 2.5.3 (pre-installed on travis)
rvm 2.5.3
unset BUNDLE_GEMFILE
bundle update --jobs=3 --retry=3
bundle exec rake clean fetch
# restore previous ruby
rvm $CURRENT_RUBY
export BUNDLE_GEMFILE=$CURRENT_GEMFILE
bundle update --jobs=3 --retry=3
bundle exec rake compile

