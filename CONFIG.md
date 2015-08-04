# TraceView Gem Configuration

## Environment Variables

The following environment variables are detected by the traceview gem:

* `IGNORE_TRACEVIEW_WARNING` - tells the traceview gem to __not__ output the _missing TraceView libraries_ message on stack initialization

* `TRACEVIEW_GEM_VERBOSE` - sets the verbose flag (`TraceView::Config[:verbose]`) early in the gem loading process which may output valuable information

## TraceView::Config

`TraceView::Config` is a nested hash used by the traceview gem to store preferences and switches.

See [this Rails generator template file](https://github.com/appneta/oboe-ruby/blob/master/lib/rails/generators/traceview/templates/traceview_initializer.rb) for documentation on all of the supported values.

