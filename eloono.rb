require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'config/environments.rb'
require 'models/model.rb'

get '/' do
  "Just Checking it Out"
end