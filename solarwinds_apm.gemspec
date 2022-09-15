$:.push File.expand_path("../lib", __FILE__)
require "solarwinds_apm/version"

Gem::Specification.new do |s|
  s.name = %q{solarwinds_apm}
  s.version = SolarWindsAPM::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "Apache-2.0"

  s.authors = ["Maia Engeli", "Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{technicalsupport@solarwinds.com}
  s.homepage = %q{https://cloud.solarwinds.com/}
  s.summary = %q{SolarWindsAPM performance instrumentation gem for Ruby}
  s.description = <<-EOF
Automatic tracing and metrics for Ruby applications. Get started at cloud.solarwinds.com
  EOF

  s.metadata = {
      'changelog_uri'     => 'https://github.com/appoptics/appoptics-apm-ruby/releases',
      'documentation_uri' => 'https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent',
      'homepage_uri'      => 'https://cloud.solarwinds.com/',
      'source_code_uri'   => 'https://github.com/appoptics/appoptics-apm-ruby',
  }

  s.extra_rdoc_files = ['LICENSE']
  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^(test|gemfiles)/}) }
  s.files += ['ext/oboe_metal/src/oboe.h',
              'ext/oboe_metal/src/oboe_api.cpp',
              'ext/oboe_metal/src/oboe_api.h',
              'ext/oboe_metal/src/oboe_debug.h',
              'ext/oboe_metal/src/oboe_swig_wrap.cc',
              'ext/oboe_metal/src/bson/bson.h',
              'ext/oboe_metal/src/bson/platform_hacks.h',
              'ext/oboe_metal/src/VERSION',
              'ext/oboe_metal/lib/liboboe-1.0-alpine-x86_64.so.0.0.0.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-x86_64.so.0.0.0.sha256'
             ]
  s.files -= ['build_gem.sh',
              'build_gem_upload_to_packagecloud.sh',
              'Rakefile']

  s.extensions = ['ext/oboe_metal/extconf.rb']

  # this still gives a warning, would have to be pinned to a minor version
  # but that is not necessary and may restrict other gems
  s.add_runtime_dependency('json', '~> 2.0')
  s.add_runtime_dependency('no_proxy_fix', '~> 0.1.2', '>= 0.1.2')

  s.required_ruby_version = '>= 2.5.0'
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
end
