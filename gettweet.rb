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



				s.save
						
				# set tweet source to soruce that you just createed or found
				t.source_id = s.id
@users = User.find(:all, :conditions => ["active_scoring <> ?", "yes"])

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