#!/usr/bin/env bash
# builds the appoptics_apm gem for MRI.

# we currently only build for MRI, no JRuby
echo -e "\n=== building for MRI ===\n"
rm -f Gemfile.lock
bundle install --without development --without test
bundle exec rake distclean
bundle exec rake fetch_ext_deps
gem build appoptics_apm.gemspec

echo -e "\n=== built gems ===\n"
ls -la appoptics_apm*.gem

echo -e "\n=== publish to rubygems via: gem push <gem> ===\n"
