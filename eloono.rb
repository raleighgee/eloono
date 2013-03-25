########## REQUIRES ########## 
require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'active_record'
require 'uri'

require_relative "./models/system_ignore_word"
require_relative "./models/link"


########## DB SETUP ########## 
db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

ActiveRecord::Base.establish_connection(
  :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
  :host     => db.host,
  :port     => db.port,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
)


########## MVC CODE ########## 
get '/' do
  "Just Checking it Out"
end

get '/submit' do
  @link = Link.create!(:tweet_id => 316846121321, :expanded_url => "yahoo.com", :source_id => 1, :user_id => 1)
  if @link.save
    redirect '/'
  else
    "Sorry, there was an error!"
  end
end