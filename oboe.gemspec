$:.push File.expand_path("../lib", __FILE__)
require "oboe/version"

Gem::Specification.new do |s|
  s.name = %q{oboe}
  s.version = Oboe::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "AppNeta Open License, Version 1.0"

  s.authors = ["Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{traceviewsupport@appneta.com}
  s.homepage = %q{http://www.appneta.com/application-performance-management}
  s.summary = %q{AppNeta TraceView performance instrumentation gem for Ruby}
  s.description = %q{The oboe gem provides TraceView instrumentation for Ruby and Ruby frameworks.}

  s.extra_rdoc_files = ["LICENSE"]
  s.files = `git ls-files`.split("\n")
  s.test_files  = Dir.glob("{test}/**/*.rb")
    
  s.extensions = ['ext/oboe_metal/extconf.rb']
   
  s.add_development_dependency 'rake'

  s.add_runtime_dependency('json', '>= 0')
end

