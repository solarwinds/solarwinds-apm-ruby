# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

# This test Padrino stack file was taken from the padrino-core gem.
#
PADRINO_ROOT = File.dirname(__FILE__) unless defined? PADRINO_ROOT
# Remove this comment if you want do some like this: ruby PADRINO_ENV=test app.rb
#
# require 'rubygems'
# require 'padrino-core'
# require 'solarwinds_apm'
#

class SimpleDemo < Padrino::Application
  set :public_folder, File.dirname(__FILE__)
  set :reload, false
  before { true }
  after  { true }
  error(404) { "404" }
end

SimpleDemo.controllers do
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
    render :erb, "The Id is #{params[:id]}"
  end

  get "/render/:id/what" do
    render :erb, "WOOT is #{params[:id]}"
  end

  get :symbol_route do
    render :erb, "This is an erb render"
  end

  get :symbol_route, :with => :id do
    render :erb, "The Id is #{params[:id]}"
  end

  get "/break" do
    raise "This is a controller exception!"
  end

  get "/error" do
    status 500
    render :erb, "broken"
  end
end

SimpleDemo.controllers :product, :parent => :user do
  get :index do
    # url is generated as "/user/#{params[:user_id]}/product"
    # url_for(:product, :index, :user_id => 5) => "/user/5/product"
    render :erb, "The user id is #{params[:user_id]}"
  end

  get :show, :with => :id do
    # url is generated as "/user/#{params[:user_id]}/product/show/#{params[:id]}"
    # url_for(:product, :show, :user_id => 5, :id => 10) => "/user/5/product/show/10"
    render :erb, "Ids: #{params[:user_id]}, #{params[:id]}"
  end
end

## If you want use this as a standalone app uncomment:
#
# Padrino.mount("SimpleDemo").to("/")
# Padrino.run! unless Padrino.loaded? # If you enable reloader prevent to re-run the app
#
# Then run it from your console: ruby -I"lib" test/frameworks/apps/padrino_simple.rb
#

Padrino.load!

