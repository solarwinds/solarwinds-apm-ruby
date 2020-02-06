#!/bin/bash

set -e # (exit immediatly on failure)
source ~/.profile
# store current ruby
CURRENT_RUBY=`rvm current`
# set ruby to 2.5.3 (pre-installed on travis)
rvm 2.5.3
gem uninstall bundler --quiet -x && gem install bundler -v 1.17.3
bundle update --jobs=3 --retry=3
bundle exec rake clean fetch
# restore previous ruby
rvm $CURRENT_RUBY
rm -f gemfiles/*.lock
bundle update --jobs=3 --retry=3
bundle exec rake compile

