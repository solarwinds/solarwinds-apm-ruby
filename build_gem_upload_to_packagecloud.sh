#!/bin/bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

# build the gem,
# oboe/c-lib version can be given as optional parameter
if [ "$1" != "" ]; then
  OBOE_VERSION=$1 ./build_gem.sh
else
  ./build_gem.sh
fi

gem install package_cloud --no-document

# prerequisite: package_cloud token needs to be in ~/.packagecloud
gem=`ls -dt1 builds/solarwinds_apm-[^pre]*.gem | head -1`
package_cloud push solarwinds/solarwinds-apm-ruby $gem
