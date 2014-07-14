require 'grape'

class GrapeSimple < Grape::API
  set :reload, true

  get '/json_endpoint' do
    present({ :test => true })
  end
end

use GrapeSimple

