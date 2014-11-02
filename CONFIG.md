# Oboe Gem Configuration

# Environment Variables

The following environment variables are detected by the oboe gem:

* `IGNORE_TRACEVIEW_WARNING` - This existence of this environment variable tells the 
oboe gem to not output the "missing TraceView libraries" message on stack initialization

* `OBOE_GEM_VERBOSE` - The existence of this environment variable sets the verbose flag
(`Oboe::Config[:verbose]`)before gem load which may output valuable information during gem load.


