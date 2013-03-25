########## REQUIRES ########## 
require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'active_record'
require 'uri'


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

post '/submit' do
  @sysword = SystemIgnoreWords.create!(:word => "the")
  if @sysword.save
    redirect '/'
  else
    "Sorry, there was an error!"
  end
end