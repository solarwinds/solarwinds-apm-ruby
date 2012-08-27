Gem::Specification.new do |s|
    s.name = %q{oboe}
    s.version = "0.3.0"
    s.date = %{2012-08-27}
    s.authors = ["Tracelytics, Inc."]
    s.email = %q{contact@tracelytics.com}
    s.summary = %q{Tracelytics Oboe API for Ruby}
    s.homepage = %q{http://tracelytics.com}
    s.description = %q{Tracelytics Oboe API for Ruby}
    s.extensions << "extconf.rb"
    s.extra_rdoc_files = ["LICENSE"]
    s.files = ["LICENSE", "extconf.rb", "oboe.hpp", "oboe_wrap.cxx", "lib/oboe.rb"]
end
