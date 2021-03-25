##
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

#  This is a Rails stack that launches on a background
#  thread and listens on port 8140.

require "rails/all"
require "active_record"
require "action_controller" # require more rails if needed
require 'rack/handler/puma'
require File.expand_path(File.dirname(__FILE__) + '/../models/widget')

class ApplicationController < ActionController::Base
  before_action :set_view_path

  private

  def set_view_path
    prepend_view_path "#{File.dirname(__FILE__)}/app/views/"
  end
end

AppOpticsAPM.logger.info "[appoptics_apm/info] Starting background utility rails app on localhost:8140."

if ENV['DBTYPE'] == 'mysql2'
  AppOpticsAPM::Test.set_mysql2_env
elsif ENV['DBTYPE'] =~ /postgres/
  AppOpticsAPM::Test.set_postgresql_env
else
  AppOpticsAPM.logger.warn "[appoptics_apm/rails] Unidentified DBTYPE: #{ENV['DBTYPE']}"
  AppOpticsAPM.logger.debug "[appoptics_apm/rails] Defaulting to postgres DB for background Rails server."
  AppOpticsAPM::Test.set_postgresql_env
end

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

unless ActiveRecord::Base.connection.table_exists? 'widgets'
  ActiveRecord::Migration.run(CreateWidgets)
end

class Rails50MetalStack < Rails::Application
  routes.append do
    get "/hello/world"       => "hello#world"
    get "/hello/with_partial" => "hello#with_partial"
    get "/hello/:id/show"    => "hello#show"
    get "/hello/metal"       => "ferro#world"
    get "/hello/db"          => "hello#db"
    get "/hello/error"       => "hello#error"
    get "/hello/servererror" => "hello#servererror"

    get "/wicked"   => "wicked#show"

    get "/widgets"          => "widgets#all"
    get "/widgets/delete_all" => "widgets#delete_all"
    post "/widgets"          => "widgets#create"
    get "/widgets/:id"       => "widgets#show"
    put "/widgets/:id"       => "widgets#update"
    delete "/widgets/:id"    => "widgets#destroy"
  end

  config.cache_classes = true
  config.eager_load = false
  config.active_support.deprecation = :stderr
  config.middleware.delete Rack::Lock
  config.middleware.delete ActionDispatch::Flash
  config.secret_token = "49837489qkuweoiuoqwehisuakshdjksadhaisdy78o34y138974xyqp9rmye8yrpiokeuioqwzyoiuxftoyqiuxrhm3iou1hrzmjk"
  config.secret_key_base = "2048671-96803948"
  # config.active_record.sqlite3 = {} # deal with https://github.com/rails/rails/issues/37048
  config.assets.enabled = false
end

#################################################
#  Controllers
#################################################

class HelloController < ApplicationController
  def world
    render :plain => "Hello world!"
  end

  def show
    render :plain => "Hello Number #{params[:id]}"
  end

  def with_partial
    render partial: "somepartial"
  end

  def db
    # Create a widget
    w1 = Widget.new(:name => 'blah', :description => 'This is an amazing widget.')
    w1.save

    # query for that widget
    w2 = Widget.where(:name => 'blah').first
    w2.delete

    render :plain => "Hello database!"
  end

  def error
    render :json => { :error => 0/0 }
  end

  def servererror
    render :plain => "broken", :status => 500
  end
end

class WickedController < ApplicationController
  def show
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "file_name", file: "#{File.dirname(__FILE__)}/app/views/test.html"
      end
    end
  end
end

class WidgetsController < ApplicationController
  protect_from_forgery with: :null_session

  def self.controller_path
    "hello" # change path from app/views/user_posts to app/views/posts
  end

  def all
    Widget.new(:name => 'This one', :description => 'This is an amazing widget.').save
    Widget.new(:name => 'This two', :description => 'This is an amazing widget.').save
    Widget.new(:name => 'This three', :description => 'This is an amazing widget.').save
    @widgets = Widget.all
    render partial: "widget", collection: @widgets
  end

  def show
    if widget = Widget.find(params[:id].to_i)
      render :json => widget
    else
      render :json => { :error => 'Widget NOT found' }, :status => 500
    end
  end

  def update
    if widget = Widget.update(params[:id].to_i, widget_params.to_h.symbolize_keys)
      render :json => widget
    else
      render :json => { :error => 'Widget NOT updated' }, :status => 500
    end
  end

  def create
    widget = Widget.new(widget_params.to_h.symbolize_keys)
    if widget.save
      render :json => widget
    else
      render :json => { :error => 'Widget NOT created' }, :status => 500
    end
  end

  def destroy
    if Widget.delete(params[:id].to_i) != 0
      render :plain => 'Widget destroyed'
    else
      render :plain => 'Widget NOT destroyed', :status => 500
    end
  end

  def delete_all
    Widget.delete_all
    render plain: 'All widgets destroyed'
  end

  private

  def widget_params
    params.require(:widget).permit(:name, :description)
  end

end

class FerroController < ActionController::Metal
  include AbstractController::Rendering

  def world
    render :plain => 'Hello world!'
  end
end

AppOpticsAPM::SDK.trace_method(FerroController, :world)

# this is a stupid solution for not having any assets
`mkdir -p app/assets/config && echo '{}' > app/assets/config/manifest.js`
Rails50MetalStack.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails50MetalStack.to_app, :Host => '127.0.0.1', :Port => 8140)
end

sleep(2)
