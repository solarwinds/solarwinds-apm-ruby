#!/bin/sh
#
# for use only when you're ready to push from prod -> the public gem repo
#

if [ $(git branch -a | grep ^* | awk '{print $2}') != "prod" ]; then
  echo "You can only push from prod."
  exit
fi

if [ $# -ne 1 ]
then
  echo "Usage: `basename $0` [../path/to/packages]"
  echo "pass me the path to your local copy of the packages repo, trailing slash omitted pls"
  exit $E_BADARGS
fi

#set -e # stop on first non-zero exit code
#set -x # show commands as they happen

# check package version
VERSION=$(grep version oboe.gemspec | sed 's/.*"\(.*\)"/\1/')

# tag release (if tag already exists, bails out)
if ! git tag rel-$VERSION; then
  echo "Couldn't create tag for ${VERSION}: if it already exists, you need to bump the version."
  exit
fi
git push --tags

# publish package
gem build oboe.gemspec
sudo cp oboe-$VERSION.gem /www/gem/gems
sudo gem generate_index -d /www/gem
