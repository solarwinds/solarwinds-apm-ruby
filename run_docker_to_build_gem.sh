#!/bin/bash

# to build the image:
# docker build -f Dockerfile -t buildgem .

docker run -it  -v `pwd`:/code/ruby-appoptics buildgem bash -l

# to build the agent gems:
# git clean -idX --  remove Gemfile.lock and downloaded extension deps
# docker run --rm  -v `pwd`:/code/ruby-appoptics buildgem bash -l -c 'cd /code/ruby-appoptics && ./build_gems.sh'
