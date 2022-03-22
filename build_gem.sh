#!/usr/bin/env bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

# builds the solarwinds_apm gem for MRI.

# we currently only build for MRI, no JRuby
echo -e "\n=== building for MRI ===\n"
rm -f Gemfile.lock
bundle install --without development --without test
bundle exec rake distclean
bundle exec rake fetch_ext_deps
gem build solarwinds_apm.gemspec
mv solarwinds_apm*.gem builds

echo -e "\n=== last 5 built gems ===\n"
ls -lart builds/solarwinds_apm*.gem | tail -n 5

echo -e "\n=== SHA256 ===\n"
gem=`ls -dt1 builds/solarwinds_apm-[^pre]*.gem | head -1`
echo `shasum -a256 $gem`

echo -e "\n=== publish to rubygems via: gem push <gem> ===\n"
