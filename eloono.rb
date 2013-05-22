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
  		@tweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true)
  	else
  	  @tweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true, :since_id => user.latest_tweet_id.to_i )
  	end
  	
  	# use Twitter api to pull last 200 tweets from current user in loop
  	
  	# declare tweet code variable
  	@tweetcode = ""
  	
  	# loop through Tweets pulled
  	@tweets.each do |p|
  	  
  	  # Check if tweet was created by current user
  		unless p.user.id == user.uid
  		  
  		  # set user latest tweet
  		  if p.id.to_i > user.latest_tweet_id.to_i
  		    user.latest_tweet_id = p.id.to_i
  		    user.save
  		  end
  		    		
  			# Update user's and connection's count of tweets shown
  		  user.num_tweets_shown = user.num_tweets_shown.to_i+1
  			user.save
		  
		    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
  		  @words =  p.full_text.split(" ")
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
    		end # end loop through words
    		
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

        c.total_tweets_seen = c.total_tweets_seen.to_f+1
        c.save        
        
			end # end check if tweet was created by user  
  	end # end loop through tweets
  		  
		@atweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true)
		@atweets.each do |p|
		  # Check if tweet was created by current user
    	unless p.user.id == user.uid
		    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
        @words =  p.full_text.split(" ")
        
        # Loop through words to create wording for links
        followwords = ""
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
                    followwords = followwords.to_s+"-"+cleanword.to_s
    							end # end check if word is on the system ignore list
    						end # End check if word is empty
    					end # End check if word is just a number
    				end # End check if word contains the @ symbol
    			end # End check if word is a link
    		end # end loop through words
        
        # reset cleantweet variable instance
        cleantweet = ""
        # begin looping through words in tweetto build clean tweet
        @words.each do |w|
          # if the number of words in the tweet is less than 3, set the tweet content to exactly what the tweet says - no clean required
        	if @words.size < 3
        		cleantweet = p.full_text
        	else
        		# build clean version of tweet
        		if w.include? %{http}
        			cleantweet = cleantweet.to_s+%{<a href="http://eloono.com/follow?l=}+w.to_s+%{&w=}+followwords.to_s+%{&u=}+user.id.to_s+%{" target="_blank" title="}+w.to_s+%{">[...]</a> }
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
        					cleantweet = cleantweet.to_s+%{<a href="http://twitter.com/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
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
        				cleantweet = cleantweet.to_s+%{<a href="https://twitter.com/search/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
        			else
        				cleantweet = cleantweet.to_s+w.to_s+" "
        			end
        		else
        			cleantweet = cleantweet.to_s+w.to_s+" "
        		end
        	end # End check if tweet is smaller than 3 words
        end # End create clean tweet
        @tweetcode = @tweetcode.to_s+cleantweet.to_s+%{<br /><br />} 		
  		end # end check if tweet was created by user  
  	end # end loop through tweets
  	
  	# Aggregate word scores
  	@words = Word.find(:all, :conditions => ["user_id = ?", user.id])
  	for word in @words
  	  if word.follows > 0 
  	    word.score = word.seen_count*(word.follows+1)
  	  else
  	    word.score = word.seen_count
  	  end
  	  word.save
  	end # end loop through words to aggregate scores
  	
  	# Build top words list
  	@twords = Word.find(:all, :conditions => ["user_id = ?", user.id], :limit => 10, :order => "score DESC")
  	@topwords = ""
  	for tword in @twords
      @topwords = @topwords.to_s+%{<br /><br />}
  	end # end lopp through top ten words
  	
  	# Update user's word scoring ranges and last interaction time
  	user.last_interaction = Time.now
  	wmaxscore = Word.maximum(:score, :conditions => ["user_id = ?", user.id])
  	wminscore = Word.minimum(:score, :conditions => ["user_id = ?", user.id])
  	wavgscore = Word.average(:score, :conditions => ["user_id = ?", user.id])
  	oneq = (wminscore.to_f+wavgscore.to_f)/2
  	threeq = (wmaxscore.to_f+wavgscore.to_f)/2
  	user.avg_word_score = wavgscore
		user.min_word_score = wminscore
		user.max_word_score = wmaxscore
		user.firstq_word_score = oneq
		user.thirdq_word_score = threeq	
  	user.save
  	
  	erb :tweets
  
  else
    redirect %{http://eloono.com}
  end # end check if a user exists in the session
  
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