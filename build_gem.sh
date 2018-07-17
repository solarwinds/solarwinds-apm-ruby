#!/usr/bin/env bash
# builds the appoptics_apm gem for MRI.

echo -e "\n=== building for MRI ===\n"
export RBENV_VERSION=2.3.1
rm -f Gemfile.lock
bundle install
bundle exec rake distclean
bundle exec rake fetch_ext_deps
gem build appoptics_apm.gemspec

echo -e "\n=== built gems ===\n"
ls -la appoptics_apm*.gem

echo -e "\n=== publish to rubygems via: gem push <gem> ===\n"
