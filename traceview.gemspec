$:.push File.expand_path("../lib", __FILE__)
require "traceview/version"

Gem::Specification.new do |s|
  s.name = %q{traceview}
  s.version = TraceView::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "AppNeta Open License, Version 1.0"

  s.authors = ["Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{traceviewsupport@appneta.com}
  s.homepage = %q{http://www.appneta.com/products/traceview/}
  s.summary = %q{AppNeta TraceView performance instrumentation gem for Ruby}
  s.description = %q{The TraceView gem provides performance instrumentation for MRI Ruby, JRuby and related frameworks.}

  s.extra_rdoc_files = ["LICENSE"]
  s.files = `git ls-files`.split("\n")
  s.test_files  = Dir.glob("{test}/**/*.rb")

  s.platform   = defined?(JRUBY_VERSION) ? 'java' : Gem::Platform::RUBY
  s.extensions = ['ext/oboe_metal/extconf.rb'] unless defined?(JRUBY_VERSION)

  s.add_runtime_dependency('json', '>= 0')
  s.add_runtime_dependency('bson', '< 4.0')
  s.add_development_dependency('rake', '>= 0')

  s.required_ruby_version = '>= 1.8.6'
end

