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
require_relative "./models/itweets"
require_relative "./models/kid"
require_relative "./models/link"
require_relative "./models/score"
require_relative "./models/source"
require_relative "./models/sysigword"
require_relative "./models/tweet"
require_relative "./models/tword"
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
  redirect '/thanks'
end

@users = User.find(:all, :conditions => ["active_scoring = ?", "yes"])
for user in @users
  tweet = Tweet.find(:first, :conditions => ["user_id = ?", user.id], :order => "created_at ASC")
  if tweet
    if tweet.created_at <= (Time.now-(60*60))
      user.active_scoring = "no"
      user.save
    end
  else
    user.active_scoring = "no"
    user.save
  end
end

@users = User.find(:all, :conditions => ["active_scoring <> ?", "yes"])

for user in @users
	
	# Set user's active scoring indicator
	user.active_scoring = "yes"
	user.save

	# Authenticate user for pulling of Tweets
	Twitter.configure do |config|
		config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
		config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
		config.oauth_token = user.token
		config.oauth_token_secret = user.secret
	end
	
	
	####################### PULL TWEETS AND CREATE SKELETONS ####################### 
	
	
	# Pull initial information about the user and load all of the people they follow into the sources table if this is the first time we've hit this user
	if user.num_score_rounds < 1
		u = Twitter.user(user.uid)
		user.handle = u.screen_name
		user.profile_image_url = u.profile_image_url
		user.language = u.lang.to_s
		#user.calls_left = Twitter.rate_limit_status.remaining_hits.to_i
		user.save
	end # end check if this is the first set of tweets fo this user
	
	# use Twitter api to pull last 200 tweets from current user in loop
	@tweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true)
	
	# loop through Tweets pulled
	@tweets.each do |p|
			  
		# Check if tweet was created by current user
		unless p.user.id == user.uid
			
			# find or create tweet
			t = Tweet.find_or_create_by_twitter_id_and_user_id_and_tweet_content(:twitter_id => p.id, :user_id => user.id, :tweet_content => p.full_text)
			t.twitter_created_at = p.created_at
			t.retweet_count = p.retweet_count
			t.reply_id = p.in_reply_to_status_id
			t.tweet_source = p.source
			t.truncated_flag = p.truncated
						
			# find or create tweet source
			s = Source.find_or_create_by_twitter_id_and_user_id(:twitter_id => p.user.id, :user_id => user.id)
			s.statuses_count = p.user.statuses_count
			s.user_screen_name = p.user.screen_name
			s.favorites_count = p.user.favorites_count
			s.profile_image_url = p.user.profile_image_url
			s.listed_count = p.user.listed_count
			s.following_flag = p.user.following
			s.user_description = p.user.description
			s.user_name = p.user.name
			s.location = p.user.location
			s.followers_count = p.user.followers_count
			s.user_url = p.user.url
			s.user_screen_name = p.user.screen_name
			s.friends_count = p.user.friends_count
			s.twitter_id = p.user.id
			s.user_language = p.user.lang
			s.user_time_zone = p.user.time_zone
			s.twitter_created_at = p.user.created_at
			s.statuses_count = p.user.statuses_count
				
			# calculate tweets per hour for source
			age_in_seconds = Time.now-s.twitter_created_at
			age_in_hours = (age_in_seconds/60)/60
			tph = s.statuses_count.to_f/age_in_hours.to_f
			s.tweets_per_hour = tph
			t.source_id = s.id
			t.save
			s.save
						
			# Parse through mentions in tweet and create any connections
			@connections = p.user_mentions
			if @connections.size > 0
				for connection in @connections
					cfollow = Source.find_by_twitter_id_and_user_id(connection.id, user.id)
					# if mention is not already a source, create a connection
					unless cfollow
					  #:twitter_id => connection.id
						c = Connection.find_or_create_by_user_screen_name_and_source_id_and_tweet_id(:user_screen_name => connection.screen_name, :source_id => s.id, :user_id => user.id, :tweet_id => t.id)
					end
				end # End loop through mentions in tweet
			end # End check tweet has any mentions

			# Check if tweet is a RT, if it is, convert source into a connection if user is not already following
			if p.retweeted_status
				t.convo_flag = "yes"
				t.reply_id = p.retweeted_status.id
				t.convo_initiator = p.retweeted_status.user.screen_name
				sfollow = Source.find_by_twitter_id_and_user_id(p.retweeted_status.user.id, user.id)
				unless sfollow
				  #:twitter_id => p.retweeted_status.user.id,
					c = Connection.find_or_create_by_user_screen_name_and_source_id_and_tweet_id(:user_screen_name => p.retweeted_status.user.screen_name, :user_name => p.retweeted_status.user.name, :source_id => s.id, :user_id => user.id, :tweet_id => t.id)
					c.save
				end
			end

			# Check if tweet is in reply to another tweet and check if user follows the soruce of the tweet that is being reponded to
			if p.in_reply_to_screen_name
				t.convo_flag = "yes"
				t.convo_initiator = p.in_reply_to_screen_name
				sfollow = Source.find_by_twitter_id_and_user_id(p.in_reply_to_user_id, user.id)
				unless sfollow
					c = Connection.find_or_create_by_user_screen_name_and_source_id_and_tweet_id(:user_screen_name => p.in_reply_to_screen_name, :source_id => s.id, :user_id => user.id, :tweet_id => t.id)
					c.save
				end
			end
					
			t.save
			
			# Check if tweet already existed in Itweets then boost user's tweet count
			olditweet = Itweets.find_by_twitter_id(t.twitter_id)
			if olditweet
			  t.destroy
			else
  			# increase current user's number of tweets by 1
  			tweets = Tweet.count(:conditions => ["user_id = ?", user.id])
  			itweets = Itweets.count(:conditions => ["user_id = ?", user.id])
  			user.num_tweets_pulled = tweets.to_i+itweets.to_i
  			user.save
  		end
			
		end # end check if tweet was created by user
	end # end loop through tweets
	
	
	####################### BUILD OUT TWEETS, WORDS AND LINKS ####################### 
	
	
	# Select all tweets that have only been loaded (e.g. last action = pulled)
	@tweets = Tweet.find(:all, :conditions => ["user_id = ? and last_action = ?", user.id, "pulled"], :order => "twitter_created_at DESC")
	
	# Loop through tweets to process words, create clean tweet version and extract links	
	
	for tweet in @tweets
	
		# split words in Tweet up using spaces
		@words = tweet.tweet_content.split(" ")

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
				
		# set clean_tweet_content version of tweet content
		tweet.clean_tweet_content = cleantweet.to_s

		# make sure tweet has at least a 0 word quailty score if it is blank
		if tweet.word_quality_score == "NULL" || tweet.word_quality_score == ""
			tweet.word_quality_score = tweet.word_quality_score.to_i+0
		end

		# Check if tweet has a link, and if so, build out links
		if tweet.tweet_content.include? %{http}
			tweet.tweet_type = "link"
			@flinks = tweet.tweet_content.split("http")
			for flink in @flinks
				if flink.include? %{://}
					@reallinks = flink.split(" ")
					boom = %{http}+@reallinks[0].to_s
					boom = boom.gsub('"','')
					l = Link.find_or_create_by_expanded_url_and_tweet_id_and_user_id(:tweet_id => tweet.id, :expanded_url => boom, :user_id => user.id, :source_id => tweet.source_id)
					l.save
				end
			end
		end # End Create links
			
		# Set the tweet type based on whether the tweet has a link or not
		haslink = Link.find_by_tweet_id(tweet.id)
		if haslink
			flinks = Link.count(:all, :conditions => ["tweet_id = ?", tweet.id])
			tweet.tweet_type = "link"
			tweet.url_count = flinks
		else
			tweet.tweet_type = "non-link"
		end
		
		# Increase source total tweets seen count by one
		source = Source.find_by_id(tweet.source_id)
		source.total_tweets_seen = source.total_tweets_seen.to_f+1
		source.save
		
		tweet.last_action = "new"
		
		tweet.save
		
	end # end loop though getting tweets
	
	####################### SCORE TWEETS ####################### 
	
	@uwords = Word.find(:all, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
	totalsees = Word.sum(:seen_count, :conditions => ["user_id = ?", user.id])
	for uword in @uwords
	  uword.score = (uword.seen_count.to_f/totalsees.to_f)*100
	  uword.save
	  uword.comp_average = uword.score.to_f+uword.follows.to_f
	  uword.save
	end # end looop through user's words
		
	if user.number_eloonos_sent < 1
	  
		# Select all tweets that have not seen the score algorithm yet (e.g. last action = new)
		@tweets = Tweet.find(:all, :conditions => ["user_id = ? and last_action = ?", user.id, "new"])			
		# Loop through "new" Tweets to score	
		for tweet in @tweets	  
			# Split the tweet's content at the spaces
			@words = tweet.tweet_content.split(" ")		    
			scoreofwords = 0
			# Loop through words in split up tweet
			@words.each do |w|
				# check if word exists
				word = Word.find_by_word(w)
			  if word
			    if word.sys_ignore_flag == "no"
				    scoreofwords = scoreofwords.to_f+word.comp_average.to_f
				  end
				end
			end # End loop through words in split up tweet    
			tweet.word_quality_score = (scoreofwords.to_f/@words.size.to_f)
			tweet.score = tweet.word_quality_score
			tweet.last_action = "scored"
			tweet.save
		end # End loop through "new" Tweets to score
		
	else # if this is not the user's first scoring round
	  
		# Get all sources for this user
		@sources = Source.find(:all, :conditions => ["user_id = ?", user.id])
	  
	  # Add ignores to sources
	  oneeloonoago = Time.now-(5*60*60)
	  for source in @sources
	    source.net_interaction_score = (source.number_links_followed.to_f-source.ignores.to_f)/source.total_tweets_seen.to_f
	    source.save
	    @sitweets = Itweets.find(:all, :conditions => ["user_id = ? and source_id = ? and last_action = ? and tweet_type = ?", user.id, source.id, "sent", "link"])
	    for sitweet in @sitweets
			  if sitweet.created_at <= oneeloonoago
    			source.ignores = source.ignores.to_i+1
    			source.save
    			sitweet.last_action = "ignored"
    			sitweet.save
    			
    			# Penalize ignored words
    			@words = sitweet.tweet_content.split(" ")
    			@words.each do |w|
    			  cleanword = w.gsub(/[^0-9a-z]/i, '')
					  cleanword = cleanword.downcase
    			  word = Word.find_by_word(cleanword)
    			  if word
    			    word.seen_count = word.seen_count.to_f*0.75
    			    word.follows = word.follows.to_f*0.75
    			    word.save
    			  end
    			end # end loop through words to penalize

        end
	    end # end loop through itweets
	  end # end loop through sources to give them number of ignores
	  	
		# Loop through user's sources to set net interaction score and average word score
		for source in @sources                
			averagetweet = 0 
			averageitweet = 0
			averagetweet = Tweet.average(:word_quality_score, :conditions => ["user_id = ? and source_id = ?", user.id, source.id])
			averageitweet = Itweets.average(:word_quality_score, :conditions => ["user_id = ? and source_id = ?", user.id, source.id])
			source.average_word_score = (averagetweet.to_f+averageitweet.to_f)/2
			source.save
		end # End loop through user's sources to set net interaction score
		
		# Rank sources by net interaction score
		ranker = 1
		lastscore = 0
		@rsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :order => "net_interaction_score ASC")
		for rsource in @rsources
			if rsource.net_interaction_score != lastscore
				ranker = ranker+1
			end
			rsource.interaction_score_rank = ranker
			rsource.save
			lastscore = rsource.net_interaction_score
		end
		
		# Rank sources by average word score
		ranker = 1
		lastscore = 0
		@rsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :order => "average_word_score ASC")
		for rsource in @rsources
			if rsource.average_word_score != lastscore
				ranker = ranker+1
			end
			rsource.word_score_rank = ranker
			rsource.save
			lastscore = rsource.average_word_score
		end
		
		# Rank sources by tph
		ranker = 1
		lastscore = 0
		@rsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :order => "tweets_per_hour DESC")
		for rsource in @rsources
			if rsource.tweets_per_hour != lastscore
				ranker = ranker+1
			end
			rsource.tph_rank = ranker
			rsource.save
			lastscore = rsource.tweets_per_hour
		end
		
		# Rank sources by followers
		ranker = 1
		lastscore = 0
		@rsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :order => "followers_count DESC")
		for rsource in @rsources
			if rsource.followers_count != lastscore
				ranker = ranker+1
			end
			rsource.num_followers_rank = ranker
			rsource.save
			lastscore = rsource.followers_count
		end
	
		# Calculate aggregate source score
    @rsources = Source.find(:all, :conditions => ["user_id = ?", user.id])
		for rsource in @rsources
      rsource.score = (((rsource.interaction_score_rank.to_f*20)+(rsource.word_score_rank.to_f*70)+(rsource.tph_rank.to_f*5)+(rsource.num_followers_rank.to_f*5))/100)/1000
			rsource.save
		end # end calculate aggregate source score
		
		# Select all tweets that have not seen the score algorithm yet (e.g. last action = new)
		@tweets = Tweet.find(:all, :conditions => ["user_id = ? and last_action = ?", user.id, "new"])			
	
		# Loop through "new" Tweets to score	
		for tweet in @tweets
				  
			# Reset tweet word quality score
			tweet.word_quality_score = 0
			tweet.save
		
			#sourceaveragewordscore = Tweet.average(:word_quality_score, :conditions => ["user_id = ? and source_id = ?", user.id, tweet.source.id])
		
			# Split the tweet's content at the spaces
			@words = tweet.tweet_content.split(" ")		    
			scoreofwords = 0
		
			# Loop through words in split up tweet
			@words.each do |w|
				# check if word exists
				word = Word.find_by_word(w)
  			if word
				  if word.sys_ignore_flag == "no"
				    scoreofwords = scoreofwords.to_f+word.comp_average.to_f
				  end
				end
			end # End loop through words in split up tweet    
			tweet.word_quality_score = (scoreofwords.to_f/@words.size.to_f)
			tweet.save
			 
			# Set tweet's source score
			tweet.source_score_score = tweet.source.score
			tweet.save
		
		end # End loop through "new" Tweets to score
		
		# Build FINAL tweet scores
		for tweet in @tweets
		  if user.number_eloonos_sent < 5
		    tweet.score = tweet.word_quality_score.to_f
		  else
		    tweet.score = ((tweet.word_quality_score.to_f*95)+(tweet.source.score.to_f*5))/100
		  end
			tweet.last_action = "scored"
			tweet.save
			
			# Add tweet socre to any associated connections
			@connections = Connection.find(:all, :conditions => ["user_id = ? and tweet_id = ?", user.id, tweet.id])
			for connection in @connections
			  connection.avg_assoc_tweet_score = (connection.avg_assoc_tweet_score.to_f+tweet.score.to_f)/2
			  connection.save
			end
			
		end
		
	end #end check is user has more than 1 score round
	
	
	
	####################### PROCESS CONNECTIONS #######################
	
	@connections = Connection.find(:all, :conditions => ["user_id = ?", user.id])
	for connection in @connections
		@cons = Connection.count(:conditions => ["user_screen_name = ? and user_id = ? and source_id = ?", connection.user_screen_name, user.id, connection.source_id])
		connection.num_appears = connection.num_appears+@cons
		connection.save
		@killcons = Connection.find(:all, :conditions => ["user_screen_name = ? and user_id = ?", connection.user_screen_name, user.id], :order => "created_at DESC")
		keep = @killcons[0].id
  	for killcon in @killcons
  		if killcon.id != keep
  			killcon.destroy
  		end
  	end
	end
	
	####################### CLEAN OUT TABLES #######################
	
	@links = Link.find(:all, :conditions => ["user_id = ?", user.id])
	if @links.size > 2000
	  num = @links.size - 2000
	  @dellinks = Link.find(:all, :conditions => ["user_id = ?", user.id], :limit => num, :order => "created_at ASC")
	  for dellink in @dellinks
	    dellink.destroy
	  end
	end
	
	@itweets = Itweets.find(:all, :conditions => ["user_id = ?", user.id])
	if @itweets.size > 2000
	  num = @itweets.size - 2000
	  @delitweets = Link.find(:all, :conditions => ["user_id = ?", user.id], :limit => num, :order => "created_at ASC")
	  for delitweet in @delitweets
	    delitweet.destroy
	  end
	end
	
	@connections = Connection.find(:all, :conditions => ["user_id = ? and user_description = ?", user.id, "wait"])
	if @connections.size > 3000
	  num = @connections.size - 3000
	  @delconnections = Connection.find(:all, :conditions => ["user_id = ? and user_description = ?", user.id, "wait"], :limit => num, :order => "created_at ASC")
	  for delconnection in @delconnections
	    delconnection.destroy
	  end
	end
	
	## Delete words that have not been followed ##
  averagescore = Word.average(:comp_average, :conditions => ["user_id = ?", user.id])
  averagefollows = Word.average(:follows, :conditions => ["user_id = ?", user.id])
	@oldwords = Word.find(:all, :conditions => ["user_id = ?", user.id])
	for oldword in @oldwords
	  if oldword.comp_average <= averagescore and oldword.sys_ignore_flag == "no" and oldword.created_at <= (Time.now-(4*60*60))
		  oldword.destroy
		end
	end	
	
	# Update user after scoring
	# user.calls_left = Twitter.rate_limit_status.remaining_hits.to_i
	user.num_score_rounds = user.num_score_rounds+1
	user.active_scoring = "no"
	user.save
	
end # end loop through users