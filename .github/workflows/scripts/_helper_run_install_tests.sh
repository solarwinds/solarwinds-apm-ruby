#!/usr/bin/env sh

# Helper script to set up dependencies for the install tests, then runs the tests.
# Accounts for:
#   * Alpine not having bash nor agent install deps
#   * Amazon Linux not having agent install deps
#   * CentOS 8 being at end-of-life and needing a mirror re-point
#   * Ubuntu not having agent install deps
#
# Note: centos8 can only install Python 3.8, 3.9

# stop on error
set -e

echo "Install solarwinds_apm version: $SOLARWINDS_APM_VERSION"

# setup dependencies quietly
{
    if grep Alpine /etc/os-release; then
        # test deps
        apk add bash
        apk --update add ruby ruby-dev build-base nodejs tzdata postgresql-dev postgresql-client libxslt-dev libxml2-dev imagemagick
    
    elif grep Ubuntu /etc/os-release; then
        ubuntu_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID="//' | sed 's/"//')
        if [ "$ubuntu_version" = "18.04" ] || [ "$ubuntu_version" = "20.04" ]; then
            apt-get update -y
            apt install -y ruby ruby-dev libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev
        else
            echo "ERROR: Testing on Ubuntu <18.04 not supported."
            exit 1
        fi
    elif  grep Debian /etc/os-release; then
        debain_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID="//' | sed 's/"//')
        if [ "$debain_version" = "11" ] || [ "$debain_version" = "12" ]; then
            apt-get update -y
            apt install -y ruby ruby-dev libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev
        else
            echo "ERROR: Testing on Debian < 11 not supported."
            exit 1
        fi

    fi
} >/dev/null

if [ "$MODE" = "RubyGem" ]; then
    echo "RubyGem"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION"
elif [ "$MODE" = "packagecloud" ]; then
    echo "packagecloud"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION" --source https://packagecloud.io/solarwinds/solarwinds-apm-ruby/
fi

if [ "$ARITCH" = "AMD" ]; then
    echo "AMD"
    ruby ./scripts/test_install.rb
elif [ "$ARITCH" = "ARM" ]; then
    echo "ARM"
    ruby ./.github/workflows/scripts/test_install.rb
fi

