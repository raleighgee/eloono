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

  user = User.find_by_id(session[:user_id])
  if user
    
    # Authenticate user for pulling of Tweets
  	Twitter.configure do |config|
  		config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
  		config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
  		config.oauth_token = user.token
  		config.oauth_token_secret = user.secret
  	end
  	
  	# Pull initial information about the user and load all of the people they follow into the sources table if this is the first time we've hit this user
  	if user.num_tweets_shown < 1
      u = Twitter.user(user.uid)
  		user.handle = u.screen_name
  		user.profile_image_url = u.profile_image_url
  		user.language = u.lang.to_s
  		user.save
  	end
  	
  	# use Twitter api to pull last 200 tweets from current user in loop
  	@tweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true)
  	
  	# loop through Tweets pulled
  	@tweets.each do |p|
  	  
  	  # Check if tweet was created by current user
  		unless p.user.id == user.uid
  		  
  			# find or create connection from tweet source
  			c = Connection.find_or_create_by_twitter_id_and_user_id(:twitter_id => p.user.id, :user_id => user.id)
  			c.profile_image_url = p.user.profile_image_url
  		  c.user_name = p.user.name
  			c.following_flag = p.user.following
  			c.user_description = p.user.description
  			c.user_url = p.user.url
  			c.user_screen_name = p.user.screen_name
  			c.user_language = p.user.lang
  			c.twitter_created_at = p.user.created_at
  			c.statuses_count = p.user.statuses_count
  			c.followers_count = p.user.followers_count
        c.friends_count = p.user.friends_count
  			c.location = p.user.location
  			c.connection_type = "following"
        
        # calculate connection's tweets per hour
        ageinhours = ((Time.now-p.user.created_at)/60)/60
        c.tweets_per_hour = p.user.statuses_count.to_f/ageinhours.to_f
  			
  		  c.save
  		  
  		  # Parse through mentions in tweet and create any connections
  			@connections = p.user_mentions
  			if @connections.size > 0
  				for connection in @connections
  					cfollow = Connection.find_by_twitter_id_and_user_id(connection.id, user.id)
  					# if mention is not already a source, create a connection
  					unless cfollow
  						m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
  					end
  				end # End loop through mentions in tweet
  			end # End check tweet has any mentions

  			# Check if tweet is a RT, if it is, convert source into a connection if user is not already following
  			if p.retweeted_status
  				cfollow = Connection.find_by_twitter_id_and_user_id(p.retweeted_status.user.id, user.id)
  				# if mention is not already a source, create a connection
  				unless cfollow
  					m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
  				end
  			end

  			# Check if tweet is in reply to another tweet and check if user follows the soruce of the tweet that is being responded to
  			if p.in_reply_to_screen_name
  				cfollow = Connection.find_by_twitter_id_and_user_id(p.in_reply_to_user_id, user.id)
  				# if mention is not already a source, create a connection
  				unless cfollow
  					m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
  				end
  			end
  			
  			# Update user's and connection's count of tweets shown
  		  user.num_tweets_shown = user.num_tweets_shown.to_i+1
  		  c.total_tweets_seen = c.total_tweets_seen.to_f+1
  		  c.save
  			user.save
  		  
  		  #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
  		  @words =  p.full_text.split(" ")
  		  # reset cleantweet variable instance
    		cleantweet = ""
    		# begin looping through words in tweet
    		@words.each do |w|
    			unless w.include? %{http}
    				unless w.include? %{@}
    					unless w.is_a? (Numeric)
    						unless w == ""
    							# remove any non alphanumeric charactes from word
    							cleanword = w.gsub(/[^0-9a-z]/i, '')
    							# check if word is on the System ignore list
    							# set all characters to lowercase
    						  cleanword = cleanword.downcase
    							sysignore = Sysigword.find_by_word(cleanword)
    							unless sysignore
    							  # look to see if word already exists, if not, create a new one using cleanword above
    							  word = Word.find_or_create_by_word_and_user_id(:word => cleanword, :user_id => user.id)
    							  # increment the number of times word has been seen counter by 1
    							  word.seen_count = word.seen_count.to_i+1
    							  word.save
    							  user.num_words_scored = user.num_words_scored+1
    							end # end check if word is on the system ignore list
    						end # End check if word is empty
    					end # End check if word is just a number
    				end # End check if word contains the @ symbol
    			end # End check if word is a link
    			# if the number of words in the tweet is less than 3, set the tweet content to exactly what the tweet says - no clean required
    			if @words.size < 3
    				cleantweet = tweet.tweet_content
    			else
    				# build clean version of tweet
    				if w.include? %{http}
    					cleantweet = cleantweet.to_s+%{[...] }
    				elsif w.include? %{@}
    					firstchar = w[0,1]
    					secondchar = w[1,1]
    					if firstchar == %{@} or secondchar == %{@}
    						if w.length.to_i > 1
    							nohandle = w.gsub('@', '')
    							nohandle = nohandle.gsub(" ", '')
    							nohandle = nohandle.gsub(":", '')
    							nohandle = nohandle.gsub(";", '')
    							nohandle = nohandle.gsub(",", '')
    							nohandle = nohandle.gsub(".", '')
    							nohandle = nohandle.gsub(")", '')
    							nohandle = nohandle.gsub("(", '')
    							nohandle = nohandle.gsub("*", '')
    							nohandle = nohandle.gsub("^", '')
    							nohandle = nohandle.gsub("$", '')
    							nohandle = nohandle.gsub("#", '')
    							nohandle = nohandle.gsub("!", '')
    							nohandle = nohandle.gsub("~", '')
    							nohandle = nohandle.gsub("`", '')
    							nohandle = nohandle.gsub("+", '')
    							nohandle = nohandle.gsub("=", '')
    							nohandle = nohandle.gsub("[", '')
    							nohandle = nohandle.gsub("]", '')
    							nohandle = nohandle.gsub("{", '')
    							nohandle = nohandle.gsub("}", '')
    							nohandle = nohandle.gsub("/", '')
    							nohandle = nohandle.gsub("<", '')
    							nohandle = nohandle.gsub(">", '')
    							nohandle = nohandle.gsub("?", '')
    							nohandle = nohandle.gsub("&", '')
    							nohandle = nohandle.gsub("|", '')
    							nohandle = nohandle.gsub("-", '')
    							cleantweet = cleantweet.to_s+%{<a href="http://twitter.com/}+nohandle.to_s+%{" target="_blank" class="embed_handle">}+w.to_s+%{</a> }
    						else
    							cleantweet = cleantweet.to_s+w.to_s+" "
    						end
    					else
    						cleantweet = cleantweet.to_s+w.to_s+" "
    					end
    				elsif w.include? %{#}
    					firstchar = w[0,1]
    					secondchar = [1,1]
    					if firstchar == %{#} or secondchar == %{#}
    						nohandle = w.gsub('#', '')
    						cleantweet = cleantweet.to_s+%{<a href="https://twitter.com/search/}+nohandle.to_s+%{" target="_blank" class="embed_handle">}+w.to_s+%{</a> }
    					else
    						cleantweet = cleantweet.to_s+w.to_s+" "
    					end
    				else
    					cleantweet = cleantweet.to_s+w.to_s+" "
    				end
    			end # End check if tweet is smaller than 3 words
    		end # End create words
  		
  		end # end check if tweet was created by user  
  	end # end loop through tweets
  	
  	user.last_interaction = Time.now
  	user.save
  	
  end # end check if a user exists in the session
  
  %{Just scored your words.}
  
end

get '/follow/:t' do
	tweet = Itweets.find_by_old_id(params[:t])
	
	if tweet
		if tweet.followed_flag != "yes"
			source = Source.find_by_id(tweet.source_id)
			source.number_links_followed = source.number_links_followed.to_i+1
			source.save
			@words = tweet.tweet_content.split(" ")
			@words.each do |w|
				cleanword = w.gsub(/[^0-9a-z]/i, '')
				cleanword = cleanword.downcase
				word = Word.find(:first, :conditions => ["word = ? and user_id = ? and sys_ignore_flag <> ?", cleanword, tweet.user_id, "yes"])
				if word
					word.follows = word.follows.to_i+1
					word.save
				end # End check if word is exists
			end # End loop through words
			tweet.followed_flag = "yes"
			tweet.last_action = "follow"
			tweet.save				
		end # End check if tweet followed flag does not = "yes"
	end # end check if a tweet is found
	
	@links = Link.find(:all, :conditions => ["tweet_id = ?", params[:t]], :order => "created_at DESC")
	if @links.size.to_i > 1
		redirect %{http://twitter.com/}+tweet.source.user_screen_name.to_s+%{/status/}+tweet.twitter_id.to_s
	else
		redirect @links[0].expanded_url
	end
	
end

get '/interact/:t' do

	tweet = Itweets.find(params[:t])
	
	if tweet
		if tweet.followed_flag != "yes"
			source = Source.find_by_id(tweet.source_id)
			source.number_links_followed = source.number_links_followed.to_i+1
			source.save
			@words = tweet.tweet_content.split(" ")
			@words.each do |w|
				cleanword = w.gsub(/[^0-9a-z]/i, '')
				cleanword = cleanword.downcase
				word = Word.find(:first, :conditions => ["word = ? and user_id = ? and sys_ignore_flag <> ?", cleanword, tweet.user_id, "yes"])
				if word
					word.follows = word.follows.to_i+1
					word.save
				end # End check if word is exists
			end # End loop through words
			tweet.followed_flag = "yes"
			tweet.last_action = "tweeted"
			tweet.save
		end # end check if tweet has already been followed
	end # end check if a tweet is found
	if params[:i] == "interact"
	  linkcode = %{https://twitter.com/intent/tweet?in_reply_to=}+tweet.twitter_id.to_s#+%{&via=}+tweet.source.user_screen_name.to_s
	else
	  linkcode = %{https://twitter.com/intent/tweet?retweet=}+tweet.twitter_id.to_s#+%{&via=}+tweet.source.user_screen_name.to_s
	end
	redirect linkcode
end

get '/ats/:word' do
  if params[:sys] == "t"
    siw = Sysigword.find_or_create_by_word(:word => params[:word])
    siw.save
  end
  word = Word.find_by_word(params[:word])
  if word
    word.score = 0
    word.comp_average = 0
    word.sys_ignore_flag = "yes"
    word.save
    if params[:sys] == "t"
      word.destroy
    end 
  end
  @code = %{<b>}+params[:word].to_s+%{</b> has been added to the system ignore list.<br /><br /><br />}
  @words = Word.find(:all, :conditions => ["user_id  = ?", 1], :limit => 10, :order => "comp_average DESC")
  for word in @words
	  @code = @code.to_s+word.word.to_s+%{ | <a href="http://eloono.com/ats/}+word.word.to_s+%{">Ignore</a>}
	  if word.user_id == 1
	    @code = @code.to_s+%{ | <a href="http://eloono.com/ats/}+word.word.to_s+%{?sys=t">Remove</a>}
	  end
	  @code = @code.to_s+%{<br /><br />}
  end # end loop through top words
  user = User.find_by_id(1)
  if user
	if user.active_scoring == "yes"
		%{Getting new words - refresh in 30 seconds.}
	else
		@code
	end
  end
end

get '/ignore_con/:id' do
  con = Connection.find_by_id(params[:id])
  if con
    con.destroy
  end
  %{Eloono will not recommend this person again.}
end

get '/test' do
  user = User.find_by_id(1)
	@links = Link.find(:all, :conditions => ["user_id = ?", 1])
	if @links.size > 2000
	  num = @links.size - 2000
	  @dellinks = Link.find(:all, :conditions => ["user_id = ?", 1], :limit => num, :order => "created_at ASC")
	  for dellink in @dellinks
	    dellink.destroy
	  end
	end
	
	@itweets = Itweets.find(:all, :conditions => ["user_id = ?", 1])
	if @itweets.size > 2000
	  num = @itweets.size - 2000
	  @delitweets = Link.find(:all, :conditions => ["user_id = ?", 1], :limit => num, :order => "created_at ASC")
	  for itweet in @itweets
	    itweet.destroy
	  end
	end
	
	@connections = Connection.find(:all, :conditions => ["user_id = ? and user_description = ?", 1, "wait"])
	if @connections.size > 3000
	  num = @connections.size - 3000
	  @delconnections = Connection.find(:all, :conditions => ["user_id = ? and user_description = ?", 1, "wait"], :limit => num, :order => "created_at ASC")
	  for delconnection in @delconnections
	    delconnection.destroy
	  end
	end
  %{OK BRO!}
end

get '/reset_users' do
  @users = User.find(:all)
  for user in @users
    user.active_scoring = "no"
    user.save
  end
  
  %{Users' Active Scoring has been Reset.}
end