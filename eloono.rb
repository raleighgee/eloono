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
require_relative "./models/source"
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
  
  %{Got it. I'll }+message.to_s
    
end

get '/con_rec/:con/:user/:action' do
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

get '/test_rec_email' do
  
	@users = User.find(:all)
	
	@connections = Connection.find(:all, :conditions => ["connection_type = ?", "reccomended"])
	for connection in @connections
	  connection.connection_type = "mentioned"
	  connection.save
	end
	
	for user in @users
	  # Authenticate user for pulling of Tweets
		Twitter.configure do |config|
			config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
			config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
			config.oauth_token = user.token
			config.oauth_token_secret = user.secret
		end
		body = ""
		@connections = Connection.find(:all, :conditions => ["user_id = ? and connection_type = ?", user.id, "mentioned"], :limit => 5, :order => "average_stream_word_score DESC")
		for connection in @connections
			c = Twitter.user(connection.user_screen_name)
			if c
				connection.twitter_id = c.id
				connection.profile_image_url = c.profile_image_url
				connection.user_name = c.name
				connection.following_flag = c.following
				connection.user_description = c.description
				connection.user_url = c.url
				connection.user_language = c.lang
				connection.location = c.location
				connection.twitter_created_at = c.created_at
				connection.statuses_count = c.statuses_count
				connection.followers_count = c.followers_count
				connection.friends_count = c.friends_count
				connection.connection_type = "reccomended"
				ageinhours = ((Time.now-c.created_at)/60)/60
				connection.tweets_per_hour = c.statuses_count.to_f/ageinhours.to_f
				connection.save
			end # end check if Twitter can find this connection
			
			ageinyears = ((((Time.now-connection.twitter_created_at)/60)/60)/24)/365
  		ftofratio = connection.friends_count.to_f/connection.followers_count.to_f
			
			body = body.to_s+%{<div style="text-align:center;"><h3>}+connection.user_screen_name.to_s+%{</h3><a href="}+connection.user_url.to_s+%{" target="_blank"><img src="}+connection.profile_image_url.to_s+%{" width="48" hegith="48" /></a><p>This is <b>}+connection.user_name.to_s+%{</b> - <i>}+connection.user_description.to_s+%{</i> They speak <b>}+connection.user_language.upcase.to_s+%{</b> and are located in <b>}+connection.location.to_s+%{</b>. They have been on Twitter for <b>}+ageinyears.to_f.round.to_s+%{</b> years and have sent <b>}+connection.statuses_count.to_f.round.to_s+%{</b> tweets at a rate of <b>}+connection.tweets_per_hour.to_f.round(2).to_s+%{</b> tweets per hour. They have <b>}+connection.friends_count.to_f.round.to_s+%{</b> friends and <b>}+connection.followers_count.to_f.round.to_s+%{</b> followers.</p><h5><a href="http://eloono.com/conrec/}+connection.id.to_s+%{/}+user.id.to_s+%{/follow" target="_blank">Follow</a> | <a href="http://eloono.com/conrec/}+connection.id.to_s+%{/}+user.id.to_s+%{/ignore" target="_blank">Ignore</a></h5></div><br />}
			
		end
		
		Pony.mail(
		  :headers => {'Content-Type' => 'text/html'},
		  :from => 'recommendations@eloono.com',
		  :to => 'raleigh.gresham@gmail.com',
		  :subject => 'Some people you might want to connect with.',
		  :body => body.to_s,
		  :port => '587',
		  :via => :smtp,
		  :via_options => { 
			:address => 'smtp.sendgrid.net', 
			:port => '587', 
			:enable_starttls_auto => true, 
			:user_name => ENV['SENDGRID_USERNAME'], 
			:password => ENV['SENDGRID_PASSWORD'], 
			:authentication => :plain, 
			:domain => ENV['SENDGRID_DOMAIN']
		  }
		)  
		
		#user.last_connectionsemail = Time.now
		#user.save
	end

  %{Boom complete}
	
end