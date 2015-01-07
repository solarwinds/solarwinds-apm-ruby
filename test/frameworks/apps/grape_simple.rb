require 'grape'

class GrapeSimple < Grape::API

  get '/json_endpoint' do
    present({ :test => true })
  end
end

