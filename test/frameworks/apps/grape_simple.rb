# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'grape'

class GrapeSimple < Grape::API
  rescue_from :all do |e|
    error_response({ message: "rescued from #{e.class.name}" })
  end

  get '/index' do
    present( )
  end

  get '/json_endpoint' do
    present({ :test => true })
  end

  get "/break" do
    raise Exception.new("This should have http status code 500!")
  end

  get "/error" do
    error!("This is an error with 'error'!")
  end

  get "/breakstring" do
    raise "This should have http status code 500!"
  end

  resource :employee_data do
    desc "List all Employee"
    get do
      present({ :employee_data => "all"})
    end

    get ':id' do
      present({ :employee_data => "Employee ##{params[:id]}"})
    end

    desc "create a new employee"
    # This takes care of parameter validation
    params do
      requires :name, type: String
      requires :address, type:String
      requires :age, type:Integer
    end
    post do
      present({ :employee_data => "Creating employee: #{params[:name]}, #{params[:address]}, #{params[:age]}"})
    end

    desc "update an employee address"
    params do
      requires :id, type: String
      requires :address, type:String
    end
    put ':id' do
      present({ :employee_data => "Updating employee ##{params[:id]}: #{params[:address]}"})
    end

    desc "delete an employee"
    params do
      requires :id, type: String
    end

    delete ':id' do
      present({ :employee_data => "Deleting employee ##{params[:id]}"})
    end

    route_param :id do
      resource :nested do
        desc "try a nested route"
        get ':child' do
          present({ :employee_data => "Nested employee data for ##{params[:id]}: #{params[:child]}"})
        end
      end
    end
  end
end

