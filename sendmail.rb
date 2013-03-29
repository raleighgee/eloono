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

@users = User.find(:all, :conditions => ["active_scoring <> ?", "yes"])
for user in @users
  fourago = Time.now #Time.now-(4*60*60)
  if user.last_interaction <= fourago
    @linktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type = ? and last_action = ?", user.id, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)
    @nonlinktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type <> ? and last_action = ?", user.id, "link", "new"], :order => "score DESC, updated_at DESC", :limit => 25)   
    
    @links = ""
    for linktweet in @linktweets
      i = Itweets.find_or_create_by_user_id_and_twitter_id(:user_id => user.id, :twitter_id => linktweet.twitter_id)
  		i.old_id = linktweet.id
  		i.source_id = linktweet.source_id
  		i.score = linktweet.score
  		i.tweet_type = linktweet.tweet_type
  		i.url_count = linktweet.url_count
  		i.followed_flag = linktweet.followed_flag
  		i.last_action = linktweet.last_action
  		i.twitter_created_at = linktweet.twitter_created_at
  		i.retweet_count = linktweet.retweet_count
  		i.tweet_source = linktweet.tweet_source
  		i.tweet_content = linktweet.tweet_content
  		i.clean_tweet_content = linktweet.clean_tweet_content
  		i.truncated_flag = linktweet.truncated_flag
  		i.reply_id = linktweet.reply_id
  		i.convo_flag = linktweet.convo_flag
  		i.convo_initiator = linktweet.convo_initiator
  		i.word_quality_score = linktweet.word_quality_score
  		i.source_score_score = linktweet.source_score_score
  		i.old_created_at = linktweet.created_at
  		i.save
    	@links = @links.to_s+%{<img src="}+linktweet.source.profile_image_url.to_s+%{" /> }+linktweet.source.user_name.to_s+%{ | }+linktweet.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/follow/}+i.old_id.to_s+%{" target="_blank">Read</a> | <a href="http://eloono.com/interact/}+i.old_id.to_s+%{" target="_blank">Interact</a><br />}
    	linktweet.destroy
    	
    	# Clean out connections that are actualy sources
			connection = Connection.find(:first, :conditions => ["user_id = ? and twitter_id = ?", i.user_id, i.source.twitter_id])
			if connection
			  connection.destroy
			end
    	
    end
    
    @nonlinks = ""
    for nonlinktweet in @nonlinktweets
      ni = Itweets.find_or_create_by_user_id_and_twitter_id(:user_id => user.id, :twitter_id => nonlinktweet.twitter_id)
  		ni.old_id = nonlinktweet.id
  		ni.source_id = nonlinktweet.source_id
  		ni.score = nonlinktweet.score
  		ni.tweet_type = nonlinktweet.tweet_type
  		ni.url_count = nonlinktweet.url_count
  		ni.followed_flag = nonlinktweet.followed_flag
  		ni.last_action = nonlinktweet.last_action
  		ni.twitter_created_at = nonlinktweet.twitter_created_at
  		ni.retweet_count = nonlinktweet.retweet_count
  		ni.tweet_source = nonlinktweet.tweet_source
  		ni.tweet_content = nonlinktweet.tweet_content
  		ni.clean_tweet_content = nonlinktweet.clean_tweet_content
  		ni.truncated_flag = nonlinktweet.truncated_flag
  		ni.reply_id = nonlinktweet.reply_id
  		ni.convo_flag = nonlinktweet.convo_flag
  		ni.convo_initiator = nonlinktweet.convo_initiator
  		ni.word_quality_score = nonlinktweet.word_quality_score
  		ni.source_score_score = nonlinktweet.source_score_score
  		ni.old_created_at = nonlinktweet.created_at
  		ni.save
    	@nonlinks = @nonlinks.to_s+%{<img src="}+ni.source.profile_image_url.to_s+%{" /> }+ni.source.user_name.to_s+%{ | }+ni.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/interact/}+ni.id.to_s+%{" target="_blank">Interact</a><br />}
    	nonlinktweet.destroy
    	
    	# Clean out connections that are actualy sources
			connection = Connection.find(:first, :conditions => ["user_id = ? and twitter_id = ?", ni.user_id, ni.source.twitter_id])
			if connection
			  connection.destroy
			end
    	
    end
    
    # Delete tweets and links that are older than four hours and have not been served
    @oldtweets = Tweet.find(:all, :conditions => ["user_id = ?", user.id])
    for oldtweet in @oldtweets
      if oldtweet.updated_at <= (Time.now-14400)
        @oldlinks = Link.find(:all, :conditions => ["tweet_id = ?", oldtweet.id])
        for oldlink in @oldlinks
          oldlink.destroy
        end # end loop through old links to delete
        oldtweet.destroy
      end # end check if tweet is four hours old or older
    end # end loop through old tweets
    
    
  end # end check if user hasn't receved an email in the last four hours
  
  ## Delete words that have not been followed ##
  twentyforhours = (Time.now-86400)
	@oldwords = Word.find(:all, :conditions => ["follows < ? and user_id = ?", 1, user.id])
	for oldword in @oldwords
	  if oldword.created_at <= twentyforhours
		  oldword.destroy
		end
	end
  
  body = %{<h1>Top 25 Link Tweets</h1>}+@links.to_s+%{<br /><br /><h1>Top 25 Non-Link Tweets</h1>}+@nonlinks.to_s

  user.last_interaction = Time.now
  user.save

  Pony.mail(
    :headers => {'Content-Type' => 'text/html'},
  	:from => 'toptweets@eloono.com',
  	:to => 'riff42@yahoo.com',
  	:subject => 'Your top Tweets from the Last Four Hours',
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
  
end # end loop through users