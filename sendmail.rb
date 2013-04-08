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

@users = User.find(:all)
for user in @users
    
  ## Delete words that have not been followed ##
  averagescore = Word.average(:comp_average, :conditions => ["user_id = ?", user.id])
  averagefollows = Word.average(:follows, :conditions => ["user_id = ?", user.id])
	@oldwords = Word.find(:all, :conditions => ["user_id = ?", user.id])
	for oldword in @oldwords
	  if oldword.comp_average <= averagescore and oldword.sys_ignore_flag == "no" and oldword.created_at <= (Time.now-(60*60))
		  oldword.destroy
		end
	end
  
  sixago = Time.now-(2*60*60)
  if user.last_interaction <= sixago
    
    @linktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type = ? and last_action = ?", user.id, "link", "scored"], :order => "score DESC, updated_at DESC", :limit => 15)
    @nonlinktweets = Tweet.find(:all, :conditions => ["user_id = ? and tweet_type <> ? and last_action = ?", user.id, "link", "scored"], :order => "score DESC, updated_at DESC", :limit => 15)   
    
    @links = ""
    for linktweet in @linktweets
      i = Itweets.find_or_create_by_user_id_and_twitter_id(:user_id => user.id, :twitter_id => linktweet.twitter_id)
  		i.old_id = linktweet.id
  		i.source_id = linktweet.source_id
  		i.score = linktweet.score
  		i.tweet_type = linktweet.tweet_type
  		i.url_count = linktweet.url_count
  		i.followed_flag = linktweet.followed_flag
  		i.last_action = "sent"
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
    	@links = @links.to_s+%{<img height="48px" width="48px" src="}+linktweet.source.profile_image_url.to_s+%{" /> <b>}+linktweet.source.user_name.to_s+%{</b> | }+linktweet.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/follow/}+i.old_id.to_s+%{" target="_blank">Read</a> | <a href="http://eloono.com/interact/}+i.id.to_s+%{" target="_blank">Interact</a><br />}
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
  		ni.last_action = "sent"
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
    	@nonlinks = @nonlinks.to_s+%{<img height="48px" width="48px" src="}+ni.source.profile_image_url.to_s+%{" /> <b>}+ni.source.user_name.to_s+%{</b> | }+ni.clean_tweet_content.to_s+%{ | <a href="http://eloono.com/interact/}+ni.id.to_s+%{" target="_blank">Interact</a><br />}
    	nonlinktweet.destroy
    	
    	# Clean out connections that are actualy sources
			connection = Connection.find(:first, :conditions => ["user_id = ? and twitter_id = ?", ni.user_id, ni.source.twitter_id])
			if connection
			  connection.destroy
			end
    	
    end
    
    # Delete tweets and links that are older than six hours and have not been served
    @oldtweets = Tweet.find(:all, :conditions => ["user_id = ?", user.id])
    for oldtweet in @oldtweets
      if oldtweet.updated_at <= (Time.now-18000)
        @oldlinks = Link.find(:all, :conditions => ["tweet_id = ?", oldtweet.id])
        for oldlink in @oldlinks
          oldlink.destroy
        end # end loop through old links to delete
        oldtweet.destroy
      end # end check if tweet is four hours old or older
    end # end loop through old tweets

    # Build list of top ten words for review
    topwords = ""
    @toptenwords = Word.find(:all, :conditions => ["user_id = ?", user.id], :order => "comp_average DESC", :limit => 10)
    for toptenword in @toptenwords
      topwords = topwords.to_s+toptenword.word.to_s+%{ | <a href="http://eloono.com/ats/}+toptenword.word.to_s+%{">Ignore</a>}
      if toptenword.user_id == 1
        topwords = topwords.to_s+%{ | <a href="http://eloono.com/ats/}+toptenword.word.to_s+%{?sys=t">Remove</a>}
      end
      topwords = topwords.to_s+%{<br /><br />}
    end # end loop through top ten top words
    
    # Find top and bottom sources
    allsources = Source.count(:all, :conditions => ["user_id = ?", user.id])
    @tsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :limit => 10, :order => "score DESC, average_word_score DESC")
    @bsources = Source.find(:all, :conditions => ["user_id = ?", user.id], :limit => 10, :order => "score ASC, average_word_score ASC")
    topsrcs = ""
    bottomsrc = ""
    
    tcount = 1
    for tsource in @tsources
      topsrcs = topsrcs.to_s+tcount.to_s+%{. <img height="48px" width="48px" src="}+tsource.profile_image_url.to_s+%{" /> <b>}+tsource.user_name.to_s+%{</b><br />}
      tcount = tcount+1
    end
    
    bcount = allsources
    for bsource in @bsources
      bottomsrcs = bottomsrcs.to_s+bcount.to_s+%{. <img height="48px" width="48px" src="}+bsource.profile_image_url.to_s+%{" /> <b>}+bsource.user_name.to_s+%{</b><br />}
      bcount = bcount-1
    end    
    
    
    # Build out body of email
    body = %{<h1>Top Ten Words</h1>}+topwords.to_s+%{<h1>Top Link Tweets</h1>}+@links.to_s+%{<br /><br /><h1>Top Non-Link Tweets</h1>}+@nonlinks.to_s+%{<br /><br /><h1>Top Sources</h1>}+topsrcs.to_s+%{<br /><br /><h1>Bottom Sources</h1>}+bottomsrcs.to_s
    
    user.number_eloonos_sent = user.number_eloonos_sent.to_i+1
    user.last_interaction = Time.now
    user.save

    Pony.mail(
      :headers => {'Content-Type' => 'text/html'},
    	:from => 'toptweets@eloono.com',
    	:to => 'raleigh.gresham@gmail.com',
    	:subject => 'Your top Tweets from the Last Few Hours',
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
    
  end # end check if user hasn't receved an email in the last four hours
  
end # end loop through users