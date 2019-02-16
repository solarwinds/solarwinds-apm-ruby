#!/bin/bash

# build the gem,
# oboe/c-lib version can be given as optional parameter
if [ "$1" != "" ]; then
  OBOE_VERSION=$1 ./build_gem.sh
else
  ./build_gem.sh
fi

# save current rbenv setting and switch to 2.4.1 for the package_cloud commands
current_ruby=`rbenv global`
rbenv global 2.4.1

# prerequisite: package_cloud token needs to be in ~/.packagecloud
gem=`ls -dt1 appoptics_apm-[^pre]*.gem | head -1`
package_cloud push solarwinds/appoptics-apm-ruby $gem

# restore ruby version
rbenv global $current_ruby
