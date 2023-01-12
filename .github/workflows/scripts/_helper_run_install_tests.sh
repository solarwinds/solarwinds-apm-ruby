#!/usr/bin/env sh

# stop on error
set -e

echo "Install solarwinds_apm version: $SOLARWINDS_APM_VERSION"

{
    if grep rhel /etc/os-release; then
        # for special ubi now. next liboboe version we will build our own rhel image
        yum update -y && yum install -y ruby-devel git-core gcc gcc-c++ make perl zlib-devel bzip2 openssl-devel

        git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
             && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
             && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
             && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
             && echo 'eval "$(rbenv init -)"' >> ~/.profile \
             && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
             && echo 'bundler' > ~/.rbenv/default-gems

        echo 'alias be="bundle exec"' >> ~/.bashrc
        echo 'alias be="bundle exec"' >> ~/.profile

        . ~/.profile \
            && cd /root/.rbenv/plugins/ruby-build && git pull && cd - \
            && rbenv install $RUBY_VERSION

        rbenv global $RUBY_VERSION
    fi
} >/dev/null

rbenv local $RUBY_VERSION

if [ "$MODE" = "RubyGem" ]; then
    echo "RubyGem"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION"
elif [ "$MODE" = "packagecloud" ]; then
    echo "packagecloud"
    gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION" --source https://packagecloud.io/solarwinds/solarwinds-apm-ruby/
fi

ruby ./home/.github/workflows/scripts/test_install.rb
