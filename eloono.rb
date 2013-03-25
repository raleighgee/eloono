require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require './config/environments'
require './models/model'

get '/' do
  "Just Checking it Out"
end