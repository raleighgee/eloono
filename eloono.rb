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

["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
  get path do
    redirect '/auth/twitter'
  end
end


get '/thanks' do
	%{Thank you! We'll send you your first email shortly.}
end

########## MVC CODE ########## 
get '/' do
  "Just Checking it Out"
end

get '/get_tweets' do

	@users = User.find(:all)
	
	for user in @users
		# Authenticate user for pulling of Tweets
		Twitter.configure do |config|
			config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
			config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
			config.oauth_token = user.token
			config.oauth_token_secret = user.secret
		end
		
		# Pull initial information about the user and load all of the people they follow into the sources table if this is the first time we've hit this user
		if user.num_score_rounds < 1
			u = Twitter.user(user.uid)
			user.handle = u.screen_name
			user.profile_image_url = u.profile_image_url
			user.language = u.lang.to_s
			#user.calls_left = Twitter.rate_limit_status.remaining_hits.to_i
			user.save
			friends = Twitter.friend_ids
			friends.ids.each do |friend|
				s = Source.find_or_create_by_user_id_and_twitter_id(:twitter_id => friend, :user_id => user.id)
			end
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
				s.save
						
				# set tweet source to soruce that you just createed or found
				t.source_id = s.id
				t.save
							
				# Parse through mentions in tweet and create any connections
				@connections = p.user_mentions
				if @connections.size > 0
					for connection in @connections
						cfollow = Source.find_by_twitter_id_and_user_id(connection.id, user.id)
						# if mention is not already a source, create a connection
						unless cfollow
							c = Connection.find_or_create_by_twitter_id_and_source_id(:user_screen_name => connection.screen_name, :user_name => connection.name, :twitter_id => connection.id, :source_id => s.id, :user_id => user.id)
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
						c = Connection.find_or_create_by_user_screen_name_and_source_id(:user_screen_name => p.retweeted_status.user.screen_name, :user_name => p.retweeted_status.user.name, :twitter_id => p.retweeted_status.user.id, :source_id => s.id, :user_id => user.id)
					end
				end

				# Check if tweet is in reply to another tweet and check if user follows the soruce of the tweet that is being reponded to
				if p.in_reply_to_screen_name
					t.convo_flag = "yes"
					t.convo_initiator = p.in_reply_to_screen_name
					sfollow = Source.find_by_twitter_id_and_user_id(p.in_reply_to_user_id, user.id)
					unless sfollow
						c = Connection.find_or_create_by_user_screen_name_and_source_id(:user_screen_name => p.in_reply_to_screen_name, :twitter_id => p.in_reply_to_user_id, :source_id => s.id, :user_id => user.id)
					end
				end
						
				t.save
				
				# increase current user's number of tweets by 1
				tweets = Tweet.count(:conditions => ["user_id = ?", user.id])
				itweets = Itweets.count(:conditions => ["user_id = ?", user.id])
				user.num_tweets_pulled = tweets.to_i+itweets.to_i
				user.save
				
			end # end check if tweet was created by user
		end # end loop through tweets
	end # end loop through users
	
	render :nothing => true
	
end

get '/build_tweets' do
	@users = User.find(:all)
	for user in @users
	
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
								# set all characters to lowercase
								cleanword = cleanword.downcase
								# look to see if word already exists, if not, create a new one using cleanword above
								word = Word.find_or_create_by_word_and_user_id(:word => cleanword, :user_id => user.id)
								# check if word is on the System ignore list
								sysignore = Sysigword.find_by_word(cleanword)
								if sysignore
									word.sys_ignore_flag = "yes"
								end
								# increment the number of times word has been seen counter by 1
								word.seen_count = word.seen_count.to_i+1
								word.save
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
								#nohandle = nohandle.gsub('"','')
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
		
			tweet.last_action = "new"
			
			tweet.save
			
		end # end loop though tweets
	end # end loop through users
	
	render :nothing => true
	
end

get '/calc_scores' do
	@users = User.find(:all, :conditions => ["active_scoring <> ?", "yes"])
	for user in @users
		
		# Set user's active scoring indicator
		user.active_scoring = "yes"
		user.save
	
		if user.number_eloonos_sent < 1
			# Rebuild user's top words
			@userwords = Word.find(:all, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"], :order => "seen_count DESC")
			for userword in @userwords
				ntopword = Tword.create!(:word => userword.word, :user_id => user.id, :score => userword.seen_count)
			end
			# Rank top words for use in scoring
			ranker = 1
			lastscore = 0
			@ranks = Tword.find(:all, :conditions => ["user_id = ?", user.id], :order => "score ASC")
			for rank in @ranks
				if rank.score != lastscore
					ranker = ranker+1
				end
				rank.rank = ranker
				rank.save
				lastscore = rank.score
			end
			# Select all tweets that have not seen the score algorithm yet (e.g. last action = new)
			@tweets = Tweet.find(:all, :conditions => ["user_id = ? and last_action = ?", user.id, "new"])			
			# Loop through "new" Tweets to score	
			for tweet in @tweets	  
				# Split the tweet's content at the spaces
				@words = tweet.tweet_content.split(" ")		    
				scoreofwords = 0
				# Loop through words in split up tweet
				@words.each do |w|
					# check if word is on the System ignore list
					sysignore = Sysigword.find_by_word(w)
					unless sysignore
						# see if word is a Top 1,000 word
						ntopword = Tword.find(:first, :conditions => ["word = ? and user_id = ?", w, user.id])
						# if word is a top 1,000 word, boost tweet score
						if ntopword
							scoreofwords = scoreofwords+ntopword.rank.to_f
						end # end check if word is a top word
					end # end check if word is on the system ignore list
				end # End loop through words in split up tweet    
				tweet.word_quality_score = (scoreofwords.to_f/@words.size.to_f)
				tweet.score = tweet.word_quality_score
				tweet.save
			end # End loop through "new" Tweets to score
		else # if this is not the user's first scoring round
  		
			# Get all sources for this user
			@sources = Source.find(:all, :conditions => ["user_id = ? and user_name <> ?", user.id, "not_seen"])
		
			# Reset users top and bottom words
			@topwords = Tword.find(:all, :conditions => ["user_id = ?", user.id])
			for topword in @topwords
				topword.destroy
			end
		
			# Rebuild user's top words
			@userwords = Word.find(:all, :conditions => ["user_id = ? and follows > ? and sys_ignore_flag = ?", user.id, 0, "no"], :order => "comp_average DESC", :limit => 1000)
			for userword in @userwords
				ntopword = Tword.create!(:word => userword.word, :user_id => user.id, :score => userword.comp_average)
			end
			
			# Rank top words for use in scoring
			ranker = 1
			lastscore = 0
			@ranks = Tword.find(:all, :conditions => ["user_id = ?", user.id], :order => "score ASC")
			for rank in @ranks
				if rank.score != lastscore
					ranker = ranker+1
				end
				rank.rank = ranker
				rank.save
				lastscore = rank.score
			end
		
			# Loop through user's sources to set net interaction score and average word score
			for source in @sources                
				if source.number_of_interactions.to_f+source.ignores.to_f == 0
					source.net_interaction_score = 0
				else
					source.net_interaction_score = ((source.number_of_interactions.to_f)-(source.ignores.to_f))/(source.number_of_interactions.to_f+source.ignores.to_f)
				end
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
			@rsources = Source.find(:all, :conditions => ["user_id = ? and user_name <> ?", user.id, "not seen"], :order => "net_interaction_score ASC")
			for rsource in @rsources
				if rsource.net_interaction_score != lastscore
					ranker = ranker+1
				end
				rsource.interaction_score_rank = ranker
				rsource.save
				lastscore = rsource.net_interaction_score
			end
		
			# Rank sources by their average word score & calculate aggregate source score
			ranker = 1
			lastscore = 0
			@rsources = Source.find(:all, :conditions => ["user_id = ? and user_name <> ?", user.id, "not seen"], :order => "average_word_score ASC")
			for rsource in @rsources
				if rsource.average_word_score != lastscore
					ranker = ranker+1
				end
				rsource.word_score_rank = ranker
				lastscore = rsource.average_word_score
				rsource.score = (rsource.word_score_rank.to_f+rsource.interaction_score_rank.to_f)/2
				rsource.save
			end # end rank sources by their average word score & calculate aggregate source score
			
			# Select all tweets that have not seen the score algorithm yet (e.g. last action = new)
			@tweets = Tweet.find(:all, :conditions => ["user_id = ? and last_action = ?", user.id, "new"])			
		
			# Loop through "new" Tweets to score	
			for tweet in @tweets
		  			  
				# Reset tweet word quality score
				tweet.word_quality_score = 0
				tweet.save
			
				sourceaveragewordscore = Tweet.average(:word_quality_score, :conditions => ["user_id = ? and source_id = ?", user.id, tweet.source.id])
			
				# Split the tweet's content at the spaces
				@words = tweet.tweet_content.split(" ")		    
				scoreofwords = 0
			
				# Loop through words in split up tweet
				@words.each do |w|
			  
					# check if word is on the System ignore list
					sysignore = Sysigword.find_by_word(w)
					unless sysignore
				  
						# see if word is a Top 1,000 word
						ntopword = Tword.find(:first, :conditions => ["word = ? and user_id = ?", w, user.id])
				  
						# if word is a top 1,000 word, boost tweet score
						if ntopword
							scoreofwords = scoreofwords+ntopword.rank.to_f
						end # end check if word is a top word
					end # end check if word is on the system ignore list
				end # End loop through words in split up tweet    
				tweet.word_quality_score = (scoreofwords.to_f/@words.size.to_f)
				tweet.save
			     
				# Set tweet's source score
				tweet.source_score_score = tweet.source.score
				tweet.save
			
			end # End loop through "new" Tweets to score
			
			# Build FINAL tweet scores
			maxwordscore = Tweet.maximum(:word_quality_score, :conditions => ["user_id = ?", user.id])
			maxsourcescore = Tweet.maximum(:source_score_score, :conditions => ["user_id = ?", user.id])
			for tweet in @tweets
				maxwordscore = maxwordscore.to_f+(maxwordscore.to_f*0.1)
				wordindex = (tweet.word_quality_score.to_f/maxwordscore.to_f)*100
				sourceindex = (tweet.source_score_score.to_f/maxsourcescore.to_f)*100
				tweet.score = (wordindex.to_f+sourceindex.to_f)/2
				tweet.last_action = "scored"
				tweet.save
			end
			
		end #end check is user has more than 1 score round
		
		# Update user after scoring
		# user.calls_left = Twitter.rate_limit_status.remaining_hits.to_i
		user.num_score_rounds = user.num_score_rounds+1
		user.save
		
	end # end loop through users
	
	render :nothing => true
	
end

get '/tweets' do

	@linktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type = ? and last_action = ?", 1, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)
	@nonlinktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type <> ? and last_action = ?", 1, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)
	
	@links = ""
	for linktweet in @linktweets
		@links = @links.to_s+linktweet.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/follow/}+linktweet.id.to_s+%{" target="_blank">Follow</a><br />}
	end
	
	@nonlinks = ""
	for nonlinktweet in @nonlinktweets
		@nonlinks = @nonlinks.to_s+nonlinktweet.clean_tweet_content.to_s+%{<br />}
	end
	
	%{<h1>Top 25 Link Tweets</h1>}+@links.to_s+%{<br /><br /><h1>Top 25 Non-Link Tweets</h1>}+@nonlinks.to_s

end

get '/follow/:t' do
	tweet = Tweet.find_by_id(params[:t])
	if tweet.followed_flag != "yes"
		source = Source.find_by_id(tweet.source_id)
		source.number_links_followed = source.number_links_followed.to_i+1
		source.number_of_interactions = source.number_of_interactions.to_i+1
		source.save
		@words = tweet.tweet_content.split(" ")
		@words.each do |w|
			cleanword = w.gsub(/[^0-9a-z]/i, '')
			cleanword = cleanword.downcase
			word = Word.find(:first, :conditions => ["word = ? and user_id = ? and sys_ignore_flag <> ?", cleanword, tweet.user_id, "yes"])
			if word
				word.score = word.score.to_i+1
				word.follows = word.follows.to_i+1
				if word.word.include? %{#}
					word.score = word.score.to_i+2
				end
				word.comp_average = (word.score.to_f+word.follows.to_f+word.seen_count.to_f)/3
				word.save
			end # End check if word is exists
		end # End loop through words
		tweet.followed_flag = "yes"
		tweet.last_action = "follow"
		tweet.save
			
		i = Itweets.find_or_create_by_user_id_and_twitter_id(:user_id => tweet.user_id, :twitter_id => tweet.twitter_id)
		i.old_id = tweet.id
		i.source_id = tweet.source_id
		i.score = tweet.score
		i.tweet_type = tweet.tweet_type
		i.url_count = tweet.url_count
		i.followed_flag = tweet.followed_flag
		i.last_action = tweet.last_action
		i.twitter_created_at = tweet.twitter_created_at
		i.retweet_count = tweet.retweet_count
		i.tweet_source = tweet.tweet_source
		i.tweet_content = tweet.tweet_content
		i.clean_tweet_content = tweet.clean_tweet_content
		i.truncated_flag = tweet.truncated_flag
		i.reply_id = tweet.reply_id
		i.convo_flag = tweet.convo_flag
		i.convo_initiator = tweet.convo_initiator
		i.word_quality_score = tweet.word_quality_score
		i.source_score_score = tweet.source_score_score
		i.old_created_at = tweet.created_at
		i.save
		tweet.destroy
			
	end # End check if tweet followed flag does not = "yes"
	@links = Link.find(:all, :conditions => ["tweet_id = ?", tweet.id], :order => "created_at DESC")
	if tweet.url_count.to_i > 1
		redirect %{http://twitter.com/}+tweet.source.user_screen_name.to_s+%{/status/}+tweet.twitter_id.to_s
	else
		redirect @links[0].expanded_url
	end
end


get '/sendmail' do
	Pony.mail(
		:from => 'raleigh.gresham@gmail.com',
		:to => 'riff42@yahoo.com',
		:subject => 'The Tweets You Should Be Reading',
		:body => 'This is where the tweets will go',
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
end