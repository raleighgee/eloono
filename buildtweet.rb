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