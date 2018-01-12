#!/bin/bash

# to build the image:
docker build -f Dockerfile -t buildgem .

# build the gems in the image
docker run --rm  -v `pwd`:/code/ruby-appoptics buildgem bash -l -c 'cd /code/ruby-appoptics && ./build_gems.sh'

# save current rbenv setting and switch to 2.4.1 for the package_cloud commands
current_ruby=`rbenv local`
rbenv local 2.4.1

# prerequisite: package_cloud tocken needs to be in ~/.packagecloud

gem=`ls -dt1 appoptics_apm*.gem | head -1`

package_cloud push AppOptics/apm-instrumentation $gem

# restore ruby version
rbenv local $current_ruby
