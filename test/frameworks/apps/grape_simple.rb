require 'grape'

class GrapeSimple < Grape::API
  set :reload, true
  use Oboe::Rack
  
  get '/json_endpoint' do
    present({ :test => true })
  end
end

use GrapeSimple

