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

@users = User.find(:all, :conditions => ["active_scoring <> ?", "yes"])
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
	user.active_scoring = "no"
	user.save
	
end # end loop through users

render :nothing => true