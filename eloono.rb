require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require_relative 'config/environments'


get '/' do
  "Just Checking it Out"
end