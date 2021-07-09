#!/usr/bin/env bash

# read versions file
# for each version

dir=`dirname $0`
while read p; do
    echo
    echo
    echo "***** grpc gem version ${p} *****"
#    replace version in gemfiles/library.gemfile
    sed -i "s/gem 'grpc', '.*'/gem 'grpc', '${p}'/g" gemfiles/libraries.gemfile
    bundle --quiet
    bundle exec ruby -Itest test/instrumentation/grpc_test.rb -n /0001/
done < $dir/versions.txt
