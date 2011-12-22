Gem::Specification.new do |s|
    s.name = %q{oboe}
    s.version = "0.2.3"
    s.date = %{2011-09-12}
    s.authors = ["Tracelytics, Inc."]
    s.email = %q{contact@tracelytics.com}
    s.summary = %q{Tracelytics Oboe API for Ruby}
    s.homepage = %q{http://tracelytics.com}
    s.description = %q{Tracelytics Oboe API for Ruby}
    s.extensions << "extconf.rb"
    s.files = ["extconf.rb", "oboe.hpp", "oboe_wrap.cxx", "lib/oboe.rb"]
end
