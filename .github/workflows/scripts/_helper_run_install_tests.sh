#!/usr/bin/env sh

# stop on error
set -e

echo "Install solarwinds_apm version: $SOLARWINDS_APM_VERSION"

# setup dependencies quietly
# {
#     if grep Alpine /etc/os-release; then
#         # test deps
#         apk add bash && apk --update add ruby ruby-dev build-base

#     elif grep Ubuntu /etc/os-release; then
#         ubuntu_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID="//' | sed 's/"//')
#         if [ "$ubuntu_version" = "18.04" ] || [ "$ubuntu_version" = "20.04" ]; then
#             apt update && apt install -y ruby ruby-dev build-essential
#         else
#             echo "ERROR: Testing on Ubuntu <18.04 not supported."
#             exit 1
#         fi
#     elif  grep Debian /etc/os-release; then
#         debain_version=$(grep VERSION_ID /etc/os-release | sed 's/VERSION_ID="//' | sed 's/"//')
#         if [ "$debain_version" = "11" ] || [ "$debain_version" = "12" ]; then
#             apt update && apt install -y ruby ruby-dev build-essential
#         else
#             echo "ERROR: Testing on Debian < 11 not supported."
#             exit 1
#         fi
#     fi
# } >/dev/null

rbenv versions
rbenv local $RUBY_VERSION

if [ "$MODE" = "RubyGem" ]; then
    echo "RubyGem"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION"
elif [ "$MODE" = "packagecloud" ]; then
    echo "packagecloud"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION" --source https://packagecloud.io/solarwinds/solarwinds-apm-ruby/
fi

ruby ./home/.github/workflows/scripts/test_install.rb

# if [ "$ARCHITECTURE" = "AMD" ]; then
#     echo "AMD"
#     ruby ./scripts/test_install.rb
# elif [ "$ARCHITECTURE" = "ARM" ]; then
#     echo "ARM"
#     ruby ./.github/workflows/scripts/test_install.rb
# fi
