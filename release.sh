#!/bin/sh
#
# for use only when you're ready to push from prod -> the public pypi
#

if [ $(git branch -a | grep ^* | awk '{print $2}') != "prod" ]; then
  echo "You can only push from prod."
  exit
fi

#set -e # stop on first non-zero exit code
#set -x # show commands as they happen

# check package version
VERSION=$(grep version oboe_fu.gemspec | sed 's/.*"\(.*\)"/\1/')

# tag release (if tag already exists, bails out)
if ! git tag rel-$VERSION; then
  echo "Couldn't create tag for ${VERSION}: if it already exists, you need to bump the version."
  exit
fi
git push --tags

# publish package
gem build oboe_fu.gemspec
sudo cp oboe_fu-$VERSION.gem /www/gem/gems
sudo gem generate_index -d /www/gem
