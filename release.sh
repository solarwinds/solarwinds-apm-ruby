#!/bin/bash
#
# for use only when you're ready to push from prod -> rubygems
#

if [ $# -ne 0 ]
then
  echo -e "Usage: `basename $0`"
  echo -e "-Summary-"
  echo -e "\t This script will help you build and release a new version of the oboe Ruby gem."
  echo -e "\t It will also create a git tag with the version being released."
  echo -e ""
  echo -e "-Steps-"
  echo -e "\t 1. Update lib/oboe/version.rb with the new version you wish to release."
  echo -e "\t 2. Re-run this script without any arguments."
  echo -e ""
  echo -e "-Notes-"
  echo -e "\t You must have ~/.gem/credentials setup with the Appneta API key for Rubygems."
  echo -e "\t The API key should be titled :rubygems_appneta: in the credentials file."
  echo -e ""
  echo -e "\t Gems with letters in the build number (e.g. pre1 or beta1)will be released "
  echo -e "\t as a prerelease gem on Rubygems."
  echo -e ""
  echo -e "\t See here for an explanation on prelease gems:"
  echo -e "\t http://guides.rubygems.org/patterns/#prerelease-gems"
  exit $E_BADARGS
fi

if [ $(git branch -a | grep ^* | awk '{print $2}') != "prod" ]; then
  echo -e "You can only release gems from prod branch."
  echo -e "Do a 'git checkout prod' and try again."
  exit
fi

#set -e # stop on first non-zero exit code
#set -x # show commands as they happen

# Get gem version from lib/oboe/version.rb
VERSION=`/usr/bin/env ruby ./get_version.rb`

read -p "Are you sure you want to release oboe gem version $VERSION to Rubygems? [y/N]" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo -e ""
  
  # tag release (if tag already exists, bails out)
  echo -e "Creating git tag rel-$VERSION..."
  if ! git tag rel-$VERSION; then
    echo -e "Couldn't create tag for ${VERSION}: if it already exists, you need to bump the version."
    exit
  fi

  echo -e "Pushing tags to origin (Github)..."
  git push --tags

  # Build and publish the gem to Rubygems.org
  echo -e "Building gem..."
  gem build oboe.gemspec
  echo -e "Pushing built gem to Rubygems..."
  gem push -k rubygems_appneta oboe-$VERSION.gem
else
  echo -e ""
  echo -e "Canceled...nothing done.  Have a nice day."
fi

