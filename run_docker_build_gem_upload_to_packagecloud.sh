#!/bin/bash

# to build the image:
docker build -f Dockerfile -t buildgem .

# build the gems in the image
docker run --rm  -v `pwd`:/code/ruby-appoptics buildgem bash -l -c 'cd /code/ruby-appoptics && ./build_gems.sh'

# save current rbenv setting and switch to 2.4.1 for the package_cloud commands
current_ruby=`rbenv local`
rbenv local 2.4.1

# !!! careful we are deleting the current version ...
# prerequistite: package_cloud tocken needs to be in ~/.packagecloud
package_cloud yank librato/apm-instrumentation traceview-4.0.0-x86_64-linux.gem
package_cloud push librato/apm-instrumentation traceview-4.0.0-x86_64-linux.gem

# restore ruby version
rbenv local $current_ruby
