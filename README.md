# Tracelytics Ruby (and Ruby Frameworks) Instrumentation

```oboe``` provides instrumentation for [Ruby](http://www.ruby-lang.org/en/) and the [Rails framework](http://rubyonrails.org/), as well as other
common components used to build rails applications.

## Installing

See the [Ruby Knowedge Base article](http://support.tracelytics.com/kb/instrumenting-your-app/instrumenting-ruby-apps)
for information on how to install. Release notes can be found [here](http://support.tracelytics.com/kb/instrumenting-your-app/ruby-instrumentation-release-notes)

## Supported Technologies

Check the [support matrix](https://github.com/tracelytics/oboe-ruby/wiki/Support-Matrix) for which versions of Ruby, Rails and technologies are supported.

## Tips

General tips using, installing and debugging the oboe gem can be found [here](https://github.com/tracelytics/oboe-ruby/wiki/Ruby-Oboe-Tips).

## liboboe Linking Notes

Build instructions

  - Requires: liboboe development headers, available from the
    liboboe-dev (Ubuntu) and liboboe-devel (Red Hat) packages.

Build and install a gem the normal way:

    gem build oboe.gemspec
    gem install oboe-VERSION.gem

Compile a binary gem from a regular gem, using gem-compile [1]:

    sudo gem install gem-compile
    gem compile oboe-VERSION.gem

[1] https://github.com/frsyuki/gem-compile
