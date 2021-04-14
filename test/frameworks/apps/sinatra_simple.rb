# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'sinatra'
require "rack/cache"
require "dalli"
require 'appoptics_apm'

use Rack::Cache,
    metastore:   "memcached://#{ENV['APPOPTICS_MEMCACHED_SERVER'] || 'localhost'}:11211",
    entitystore: "memcached://#{ENV['APPOPTICS_MEMCACHED_SERVER'] || 'localhost'}:11211"

class SinatraSimple < Sinatra::Base
  set :reload, true

  template :layout do
    # Use both the legacy and new RUM helper
    # oboe_rum_header + appoptics_rum_footer
    # These should be no-op methods now.
    %q{
<html>
  <head></head>
  <body>
    <%= yield %>
  </body>
</html>}
  end

  get "/cache" do
    cache_control :public, :max_age => 10
    render :erb, "<h1>I have a header</h1>"
  end

  get "/" do
    'The magick number is: 2767356926488785838763860464013972991031534522105386787489885890443740254365!' # Change only the number!!!
  end

  get "/rand" do
    rand(2 ** 256).to_s
  end

  get "/render" do
    render :erb, "This is an erb render"
  end

  get "/render/:id" do
    render :erb, "The id is #{ params['id'] }"
  end

  get "/render/:id/what" do |id|
    render :erb, "WOOT! The id is #{id} }"
  end

  get '/say/*/to/*' do
    render :erb, "#{params['splat'][0]} #{params['splat'][1]}"
  end

  get /\/hello\/([\w]+)/ do
    render :erb, "Hello, #{params['captures'].first}!"
  end

  get "/break" do
    raise "This is a controller exception!"
  end
end

use SinatraSimple
