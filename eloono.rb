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
  %{<a href="http://eloono.com/signin">Click Here to Sign In<a/>}
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
	linkcode = %{https://twitter.com/intent/tweet?in_reply_to=}+tweet.twitter_id.to_s#+%{&via=}+tweet.source.user_screen_name.to_s
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
  @code
end

get '/test' do
  totalsees = Word.sum(:seen_count, :conditions => ["user_id = ?", 1])
  totalsees.to_s+%{ total words seen}
end

get '/reset_users' do
  @users = User.find(:all)
  for user in @users
    user.active_scoring = "no"
    user.save
  end
  
  %{Users' Active Scoring has been Reset.}
end