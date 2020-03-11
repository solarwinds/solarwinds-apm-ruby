$:.push File.expand_path("../lib", __FILE__)
require "appoptics_apm/version"

Gem::Specification.new do |s|
  s.name = %q{appoptics_apm}
  s.version = AppOpticsAPM::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "Librato Open License, Version 1.0, https://bit.ly/2Kmm0mN"

  s.authors = ["Maia Engeli", "Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{support@appoptics.com}
  s.homepage = %q{https://www.appoptics.com/}
  s.summary = %q{AppOptics APM performance instrumentation gem for Ruby}
  s.description = <<-EOF
Automatic tracing and metrics for Ruby applications. Get started at appoptics.com. @AppOptics
  EOF

  s.metadata = {
      'changelog_uri'     => 'https://github.com/appoptics/appoptics-apm-ruby/releases',
      'documentation_uri' => 'https://docs.appoptics.com/kb/apm_tracing/ruby/',
      'homepage_uri'      => 'https://www.appoptics.com/',
      'source_code_uri'   => 'https://github.com/appoptics/appoptics-apm-ruby',
  }

  s.extra_rdoc_files = ['LICENSE']
  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^(test|gemfiles)/}) }
  s.files += ['ext/oboe_metal/src/oboe.h',
              'ext/oboe_metal/src/oboe.cxx',
              'ext/oboe_metal/src/oboe.hpp',
              'ext/oboe_metal/src/oboe_debug.h',
              'ext/oboe_metal/src/oboe_wrap.cxx',
              'ext/oboe_metal/src/bson/bson.h',
              'ext/oboe_metal/src/bson/platform_hacks.h',
              'ext/oboe_metal/src/VERSION']
  s.files -= ['build_gem.sh',
              'build_gem_upload_to_packagecloud.sh',
              'Rakefile']

  # TODO this is commented out util we can actually provide gems for different platforms
  # it will create a gem that goes into noop on Darwin and other unsupported platforms
  # s.platform   = defined?(JRUBY_VERSION) ? 'java' : Gem::Platform::CURRENT

  s.extensions = ['ext/oboe_metal/extconf.rb'] unless defined?(JRUBY_VERSION)

  s.add_runtime_dependency('json', '>= 0')
  s.add_runtime_dependency('no_proxy_fix', '~> 0.1.2', '>= 0.1.2')

  # Development dependencies used in gem development & testing
  s.add_development_dependency('rake', '>= 0.9.0')
  s.add_development_dependency('simplecov', '>= 0.16.0') if ENV["SIMPLECOV_COVERAGE"]
  s.add_development_dependency('simplecov-console', '>= 0.4.0') if ENV["SIMPLECOV_COVERAGE"]
  s.add_development_dependency('irb', '>= 1.0.0', '< 1.2.2') if RUBY_VERSION >= '2.6.0'

  unless defined?(JRUBY_VERSION)
    s.add_development_dependency('byebug', '>= 11.0.0')
    s.add_development_dependency('minitest', '>= 8.0.0')
    s.add_development_dependency('minitest-hooks', '>= 1.5.0')
    s.add_development_dependency('minitest-focus', '>=1.1.2')
    s.add_development_dependency('benchmark-ips', '>= 2.7.2')
  end

  s.required_ruby_version = '>= 2.4.0'
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
end
