# Oboe Gem Configuration

## Environment Variables

The following environment variables are detected by the oboe gem:

* `IGNORE_TRACEVIEW_WARNING` - This existence of this environment variable tells the 
oboe gem to not output the "missing TraceView libraries" message on stack initialization

* `OBOE_GEM_VERBOSE` - The existence of this environment variable sets the verbose flag
(`Oboe::Config[:verbose]`)before gem load which may output valuable information during gem load.

## Oboe::Config

`Oboe::Config` is a nested hash used by the oboe gem to store preferences and switches.

See [this Rails generator template file](https://github.com/appneta/oboe-ruby/blob/master/lib/rails/generators/oboe/templates/oboe_initializer.rb) for documentation on all of the supported values.

