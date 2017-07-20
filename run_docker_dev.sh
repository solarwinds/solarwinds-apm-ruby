#!/bin/bash

# to build the image:
# docker build -f Dockerfile -t rubydev .

docker run -it  -v `pwd`:/code/ruby-tracelytics rubydev bash -l

# to build the agent gems:
# git clean -idX --  remove Gemfile.lock and downloaded extension deps
# docker run --rm  -v `pwd`:/code/ruby-tracelytics rubydev bash -l -c 'cd /code/ruby-tracelytics && ./build_gems.sh'
