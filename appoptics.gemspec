$:.push File.expand_path("../lib", __FILE__)
require "appoptics/version"

Gem::Specification.new do |s|
  s.name = %q{appoptics}
  s.version = AppOptics::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "Librato Open License, Version 1.0"

  s.authors = ["Maia Engeli", "Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{support@appoptics.com}
  s.homepage = %q{https://appoptics.solarwinds.com/}
  s.summary = %q{AppOptics performance instrumentation gem for Ruby}
  s.description = %q{The AppOptics gem provides performance instrumentation for MRI Ruby, JRuby and related frameworks.}

  s.extra_rdoc_files = ["LICENSE"]
  s.files = `git ls-files`.split("\n")
  s.files += ['ext/oboe_metal/lib/liboboe-1.0.so.0.0.0',
              'ext/oboe_metal/src/oboe.h',
              'ext/oboe_metal/src/oboe.hpp',
              'ext/oboe_metal/src/oboe_debug.h',
              'ext/oboe_metal/src/oboe_wrap.cxx',
              'ext/oboe_metal/src/VERSION']
  s.test_files  = Dir.glob("{test}/**/*.rb")

  s.platform   = defined?(JRUBY_VERSION) ? 'java' : Gem::Platform::CURRENT
  s.extensions = ['ext/oboe_metal/extconf.rb'] unless defined?(JRUBY_VERSION)

  s.add_runtime_dependency('json', '>= 0')

  # Development dependencies used in gem development & testing
  s.add_development_dependency('rake', '>= 0.9.0')

  unless defined?(JRUBY_VERSION)
    case RUBY_VERSION
    when /^1\.9/
      s.add_development_dependency('debugger', '>= 1.6.7')
      s.add_development_dependency('pry', '>= 0.10.0')
    when /^2\./
      s.add_development_dependency('byebug', '>= 8.0.0')
      s.add_development_dependency('pry', '>= 0.10.0')
      s.add_development_dependency('pry-byebug', '>= 3.0.0')
    end
  else
    s.add_development_dependency('pry', '>= 0.10.0')
  end

  s.add_development_dependency('benchmark-ips')
  s.add_development_dependency('ruby-prof')

  s.required_ruby_version = '>= 1.9.3'
end
