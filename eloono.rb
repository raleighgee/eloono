require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'environments.rb'
require 'connection.rb'

get '/' do
  "Just Checking it Out"
end