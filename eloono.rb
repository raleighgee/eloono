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


get '/tweets' do

	@linktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type = ? and last_action = ?", 1, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)
	@nonlinktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type <> ? and last_action = ?", 1, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)
	
	@links = ""
	for linktweet in @linktweets
		@links = @links.to_s+linktweet.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/follow/}+linktweet.id.to_s+%{" target="_blank">Follow</a><br />}
	end
	
	@nonlinks = ""
	for nonlinktweet in @nonlinktweets
		@nonlinks = @nonlinks.to_s+nonlinktweet.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/interact/}+nonlinktweet.id.to_s+%{" target="_blank">Join Conversation</a><br />}
	end
	
	%{<h1>Top 25 Link Tweets</h1>}+@links.to_s+%{<br /><br /><h1>Top 25 Non-Link Tweets</h1>}+@nonlinks.to_s

end

get '/follow/:t' do
	tweet = Tweet.find_by_id(params[:t])
	
	if tweet
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
	end # end check if a tweet is found
	
	@links = Link.find(:all, :conditions => ["tweet_id = ?", params[:t]], :order => "created_at DESC")
	if @links.size.to_i > 1
		redirect %{http://twitter.com/}+tweet.source.user_screen_name.to_s+%{/status/}+tweet.twitter_id.to_s
	else
		redirect @links[0].expanded_url
	end
	
end

get '/interact/:t' do

	tweet = Tweet.find_by_id(params[:t])
	
	if tweet
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
			tweet.last_action = "tweeted"
			tweet.save
			
			linkcode = %{https://twitter.com/intent/tweet?in_reply_to=}+tweet.twitter_id.to_s+%{&via=}+tweet.source.user_screen_name.to_s

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
		end # end check if tweet has already been followed
	else # if tweet is not found then...
		itweet = Itweets.find_by_old_id(params[:t])
		linkcode = %{https://twitter.com/intent/tweet?in_reply_to=}+itweet.twitter_id.to_s+%{&via=}+itweet.source.user_screen_name.to_s
	end # end check if a tweet is found
	
	redirect linkcode
	
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