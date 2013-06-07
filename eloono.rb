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
  user = User.find_by_id(session[:user_id])
  if user
    wordcode = ""
    upcode = %{<div style="position:fixed; top:53px; left:233px;"><h4>Here are the words you have told me you like:</h4>}
    word = Word.find(:first, :conditions => ["user_id = ? and thumb_status = ? and sys_ignore_flag = ?", session[:user_id], "neutral", "no"], :order => "score DESC")
    wordcode = wordcode.to_s+%{<span style="font-size:2.5em; font-family:Helvetica;">}+word.word.to_s+%{</span><br /><a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/up?src=page">+</a><br /><br /><a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/down?src=page">-</a><br /><br /><a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/ignore?src=page">x</a><br /><br />}
    @upwords = Word.find(:all, :conditions => ["user_id = ? and thumb_status = ? and sys_ignore_flag = ?", session[:user_id], "up", "no"], :order => "word ASC")
    if @upwords.size > 0
      for upword in @upwords
        upcode = upcode.to_s+%{* }+upword.word.to_s+%{<br />}
      end # end loop through upwords
      wordcode = upcode.to_s+%{</div>}+wordcode.to_s
    end # end check if any words have been thumbed up
    %{<h3>How do you feel about these words?</h3>}+wordcode.to_s
  else
      %{<a href="http://eloono.com/signin">Click Here to Sign In<a/>}
  end
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

get '/words/:id/:action' do
  
  message = ""
  word = Word.find_by_id(params[:id])
  if word
    if word.thumb_status == "neutral" && word.sys_ignore_flag == "no"
      if params[:action].to_s == "up"
        word.thumb_status = "up"
        word.save
        message = %{INCREASE the weight I use for <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
      elsif params[:action].to_s == "down"
        word.thumb_status = "down"
        word.save
        message = %{DECREASE the weight I use for <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
      elsif params[:action].to_s == "ignore"
        word.sys_ignore_flag = "yes"
        word.score = 0
        word.save
        message = %{NEVER use the word <b>"}+word.word.to_s+%{"</b> when scoring your tweets. Thanks for making me smarter!}
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
    redirect %{http://eloono.com}
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

get '/reset_users' do
  @users = User.find(:all)
  for user in @users
    user.active_scoring_flag = "no"
    user.save
  end
  %{DONE}
end

get '/onetime' do
  
  user = User.find_by_id(1)
  
  Twitter.configure do |config|
		config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
		config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
		config.oauth_token = user.token
		config.oauth_token_secret = user.secret
	end
  
  %{DONE}
end