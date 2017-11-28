FROM ubuntu:16.04

# Use this Dockerfile to create the gem
# > docker build -f Dockerfile -t buildgem .
# > docker run --rm  -v `pwd`:/code/ruby-appoptics buildgem bash -l -c 'cd /code/ruby-appoptics && ./build_gems.sh'

# install OS packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       curl \
       git-core \
       libpcre3-dev \
       libreadline-dev \
       libssl-dev \
       openjdk-8-jdk \
       zlib1g-dev \
       less \
    && rm -rf /var/lib/apt/lists/*

# rbenv setup
# use rbenv-default-gems to automatically install bundler for each ruby version
RUN  git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
     &&  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
     && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
     && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
     && echo 'eval "$(rbenv init -)"' >> ~/.profile \
     && echo 'bundler' > ~/.rbenv/default-gems

# install rubies to build our gem against
RUN .  ~/.profile \
    && rbenv install 2.3.1 \
    && rbenv install jruby-9.0.5.0

# install swig 3.0.8
RUN curl -SL http://kent.dl.sourceforge.net/project/swig/swig/swig-3.0.8/swig-3.0.8.tar.gz \
    | tar xzC /tmp \
    && cd /tmp/swig-3.0.8 \
    && ./configure && make && make install \
    && cd \
    && rm -rf /tmp/swig-3.0.8
