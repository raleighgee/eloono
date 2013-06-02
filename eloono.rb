########## REQUIRES ########## 
require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'active_record'
require 'uri'
require 'omniauth-twitter'
require 'twitter'
require 'pony'

require_relative "./models/connection"
require_relative "./models/sysigword"
require_relative "./models/user"
require_relative "./models/word"


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

########## TWITTER AUTHENTICATION ########## 

use OmniAuth::Strategies::Twitter, 'DHBxwGvab2sJGw3XhsEmA', '530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk'

enable :sessions

get '/auth/:name/callback' do
  auth = request.env["omniauth.auth"]
  user = User.find_or_create_by_uid(
    :uid => auth["uid"],
    :provider => auth["provider"],
    :token => auth["credentials"]["token"],
    :secret => auth["credentials"]["secret"],
    :name => auth["info"]["name"])
  session[:user_id] = user.id
  user.save
  user.token = auth["credentials"]["token"]
  user.secret = auth["credentials"]["secret"]
  user.save
  redirect '/tweets'
end

["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
  get path do
    redirect '/auth/twitter'
  end
end

########## MVC CODE ########## 
get '/' do
  %{<a href="http://eloono.com/signin">Click Here to Sign In<a/>}
end

get '/tweets' do
  %{You will receive and email shortly!}
end

get '/follow' do
  
  link = params[:l]
  fwords = params[:w]
  @words = fwords.split("-")
  @words.each do |w|
    word = Word.find(:first, :conditions => ["word = ? and user_id = ?", w, params[:u]])
    if word
      word.follows = word.follows.to_i+1
      word.save
    end # End check if word is exists
  end # End loop through words			
	
	redirect link
	
end

get '/top_50_words' do
  user = User.find_by_id(session[:user_id])
  if user
    wordcode = ""
    @words = Word.find(:all, :conditions => ["user_id = ? and thumb_status = ? and sys_ignore_flag = ?", session[:user_id], "neutral", "no"], :oder => "score DESC", :limit => 50)
    for word in @words
      wordcode = wordcode.to_s+word.word.to_s+%{ | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/up?src=page" target="_blank">+</a> | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/down?src=page" target="_blank">-</a> | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/ignore?src=page" target="_blank">x</a><br /><br />}
    end # end loop through words
    
    %{<h3>These are your top 50 words. What do you think?</h3>}+wordcode.to_s
  else
    redirect %{http://eloono.com}
  end
end

get '/words/:id/:action' do
  
  message = ""
  word = Word.find_by_id(params[:id])
  if word
    if word.thumb_status == "neutral" && word.sys_ignore_flag == "no"
      if params[:action].to_s == "up"
        word.thumb_status = "up"
        word.score = word.score.to_f*5
        word.save
        message = %{INCREASE the weight I use for <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
      elsif params[:action].to_s == "down"
        word.thumb_status = "down"
        word.score = word.score.to_f/5
        word.save
        message = %{DECREASE the weight I use for <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
      elsif params[:action].to_s == "ignore"
        word.sys_ignore_flag = "yes"
        word.score = 0
        word.save
        message = %{NEVER use the word <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
      elsif params[:action].to_s == "neutral"
        word.thumb_status = "neutral_final"
        word.save
        message = %{leave the weight I use for <b>"}+word.word.to_s+%{"</b> when scoring your tweets the SAME. Thanks for making me smarter!}
      end
    else
      message = %{take care of that. Thanks for making me smarter!}
    end
  else
    message = %{take care of that. Thanks for making me smarter!}
  end
  
  if params[:src] != "page"
    %{Got it. I'll }+message.to_s
  else
    redirect %{http://eloono.com/top_50_words/}+session[:user_id].to_s
  end
    
end

get '/conrec/:con/:user/:action' do
  connection = Connection.find(:first, :conditions => ["user_id = ? and id = ?", params[:user], params[:con]])
  if connection
    if params[:action] == "follow"
      connection.connection_type = "following"
      connection.save
      redirect %{http://twitter.com/}+connection.user_screen_name.to_s
    else
      connection.connection_type = "ignore"
      connection.save
      %{OK. I won't reccomend }+connection.user_screen_name.to_s+%{ to you again. Thanks for making me smarter!}
    end
  else
    %{Hmmmmm. Can't seem to find that recommendation. Sorry about that!}
  end  
end