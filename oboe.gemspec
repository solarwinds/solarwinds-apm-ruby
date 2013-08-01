$:.push File.expand_path("../lib", __FILE__)
require "oboe/version"

Gem::Specification.new do |s|
    s.name = %q{oboe}
    s.version = Oboe::Version::STRING
    s.date = Time.now.strftime('%Y-%m-%d')
    s.authors = ["Tracelytics, Inc."]
    s.email = %q{contact@tracelytics.com}
    s.summary = %q{Tracelytics instrumentation gem}
    s.homepage = %q{http://tracelytics.com}
    s.description = %q{The oboe gem provides AppNeta instrumentation for Ruby and Ruby frameworks.}
    s.extra_rdoc_files = ["LICENSE"]
    s.files = `git ls-files`.split("\n")
    s.extensions = ['ext/oboe_metal/extconf.rb']
    s.test_files  = Dir.glob("{spec}/**/*.rb")
    s.add_development_dependency 'rake'
    s.add_development_dependency 'rspec'

    s.post_install_message = "

This oboe gem requires updated AppNeta liboboe (>= 1.1.1) and 
tracelytics-java-agent packages (if using JRuby).  Make sure to update all 
of your hosts or this gem will just sit in the corner and weep quietly.

- Your Friendly AppNeta TraceView Team

"
end
