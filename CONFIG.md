# Oboe Gem Configuration

## Environment Variables

The following environment variables are detected by the oboe gem:

* `IGNORE_TRACEVIEW_WARNING` - tells the oboe gem to __not__ output the _missing TraceView libraries_ message on stack initialization

* `OBOE_GEM_VERBOSE` - sets the verbose flag (`Oboe::Config[:verbose]`) early in the gem loading process which may output valuable information

## Oboe::Config

`Oboe::Config` is a nested hash used by the oboe gem to store preferences and switches.

See [this Rails generator template file](https://github.com/appneta/oboe-ruby/blob/master/lib/rails/generators/oboe/templates/oboe_initializer.rb) for documentation on all of the supported values.

