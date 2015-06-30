By default, the TraceView oboe gem will not trace routes with extensions
for common static files.  Examples of such files may be images,
javascript, pdfs and text files.

This is done by using the regular expression stored in
`Oboe::Config[:dnt_regexp]`:

    .(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$

This string is used as a regular expression and is tested against
candidate URLs to be instrumented.

To replace the pattern in use, you can update this regular expression
string.  Here are some examples.

If you prefer that you want your javascript and CSS files instrumented,
you can update `Oboe::Config[:dnt_regexp]` with an updated regexp
pattern (without the "js" and "css" entries):

    .(jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|flv|swf|ttf|woff|svg|less)$

If you prefer to not instrument all javascript files except for one
named `show.js`, you could put this assignment into your initializer,
rackup file or application.rb (note that this example uses a standard
regexp [negative
look-behind](http://www.regular-expressions.info/lookaround.html) that
isn't supported in Ruby 1.8):

    Oboe::Config[:dnt_regexp] = "(\.js$)(?<!show.js)"

Since this pattern is used with the standard Ruby Regexp class, you can
use any Regexp supported pattern.  See the documentation on Ruby Regexp
[here](https://www.omniref.com/ruby/2.2.0/symbols/Regexp?d=380181456&n=0#doc_uncollapsed=true&d=380181456&n=0)
or you can also view the oboe gem [source code documentation for this
feature](https://github.com/appneta/oboe-ruby/blob/master/lib/oboe/config.rb#L74).
