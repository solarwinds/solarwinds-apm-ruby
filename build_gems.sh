#!/usr/bin/env bash
# builds the traceview gem for JRuby and MRI.

echo -e "\n=== building for MRI ===\n"
export RBENV_VERSION=2.3.1
rm -f Gemfile.lock
bundle install
bundle exec rake distclean
bundle exec rake fetch_ext_deps
gem build traceview.gemspec

echo -e "\n=== built gems ===\n"
ls -la traceview*.gem

echo -e "\n=== publish to rubygems via: gem push <gem> ===\n"
