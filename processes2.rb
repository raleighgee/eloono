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


#### CODE #####
@users = User.find(:all, :conditions => ["active_scoring_flag = ?", "no"])
for user in @users
  
  user.active_scoring_flag = "yes"
  user.save
  
  # Authenticate user for pulling of Tweets
	Twitter.configure do |config|
		config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
		config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
		config.oauth_token = user.token
		config.oauth_token_secret = user.secret
	end
	
	# Pull initial information about the user and load all of the people they follow into the sources table if this is the first time we've hit this user
	if user.intial_learning_complete_flag == "no"
    i = 1
    maxid = 0
    10.times do
      if i == 1 
        @tweets = Twitter.home_timeline(:count => 800, :include_entities => true, :include_rts => true)
      else
        @tweets = Twitter.home_timeline(:count => 800, :include_entities => true, :include_rts => true, :max_id => maxid.to_i)
      end
      mid = @tweets.size.to_i-1
      maxid = @tweets[mid].id.to_i
      @tweets.each do |p|
    		@words =  p.full_text.split(" ")
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
    							if word.sys_ignore_flag == "no"
      							# increment the number of times word has been seen counter by 1 and aggregate the score
      							word.seen_count = word.seen_count.to_i+1
  								  word.score = word.seen_count
      							word.save
    							end # end check if word is on the system ignore list
    						end # End check if word is empty
    					end # End check if word is just a number
    				end # End check if word contains the @ symbol
    			end # End check if word is a link       
  		  end # end loop through words
  		end # end loop through tweets
      i = i+1
    end # End iterate through intial 8000 tweets
    user.intial_learning_complete_flag = "pulled"
    user.save
  else # if user intial_learning_complete_flag <> 0 then do this
    twords = Word.count(:conditions => ["user_id = ? and thumb_status = ?", user.id, "up"])
    if twords >= 5
      user.intial_learning_complete_flag = "yes"
      if user.num_tweets_shown == 0
        u = Twitter.user(user.uid)
    		user.handle = u.screen_name
    		user.profile_image_url = u.profile_image_url
    		user.language = u.lang.to_s
    		user.save
    		@tweets = Twitter.home_timeline(:count => 800, :include_entities => true, :include_rts => true)
    	else
    	  @tweets = Twitter.home_timeline(:count => 800, :include_entities => true, :include_rts => true, :since_id => user.latest_tweet_id.to_i)
    	end # end check if this is the first time a user has had tweets scored
    	#pull user's last 800 tweets 
    	@tweets = Twitter.home_timeline(:count => 800, :include_entities => true, :include_rts => true)
    	# Reset aggregate level variables
    	@tweetcode = ""
      # loop through Tweets pulled
    	@tweets.each do |p|

    	  # Reset variables
    	  totaltweetscore = 0

  	    # set user latest tweet
    	  if p.id.to_i > user.latest_tweet_id.to_i
			    user.latest_tweet_id = p.id.to_i
    	  end

        #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
        @words =  p.full_text.split(" ")
        # begin looping through words in tweet
        @words.each do |w|
          unless w.include? %{http}
            unless w.include? %{@}
              unless w.is_a? (Numeric)
                unless w == ""
                  # remove any non alphanumeric charactes from word and set all characters to lowercase
                  cleanword = w.gsub(/[^0-9a-z]/i, '')
                  cleanword = cleanword.downcase
                  # look to see if word already exists, if not, create a new one using cleanword above
                  word = Word.find_or_create_by_word_and_user_id(:word => cleanword, :user_id => user.id)
                  if word.sys_ignore_flag == "no"
                    # increment the number of times word has been seen counter by 1 and aggregate the score
                    word.seen_count = word.seen_count.to_i+1
                    if word.follows > 0 
                      word.score = word.seen_count*(word.follows.to_f+1)
                    else
                      word.score = word.seen_count
                    end
                    if word.thumb_status == "up"
                      word.score = word.score.to_f*1.2
                    end
                    word.save
                    totaltweetscore = totaltweetscore+word.score
                    user.num_words_scored = user.num_words_scored+1
                    if p.user.id == user.uid
                      word.score = word.score.to_f*1.5
                    end
                    word.save
                  end # end check if word is on the system ignore list
                end # End check if word is empty
              end # End check if word is just a number
            end # End check if word contains the @ symbol
          end # End check if word is a link              
    		end # end loop through words
        
        # Parse through mentions in tweet and create any connections
        @connections = p.user_mentions
        if @connections.size > 0
          for connection in @connections
            cfollow = Connection.find_by_twitter_id_and_user_id_and_connection_type(connection.id, user.id, "following")
            # if mention is not already a source, create a connection
            if cfollow
              cfollow.appearances = cfollow.appearances.to_i+1
              cfollow.save
            else
              m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
              m.average_word_score = (m.average_word_score.to_f+totaltweetscore.to_f)/2
              m.appearances = m.appearances+1
              m.save
            end
          end # End loop through mentions in tweet
        end # End check tweet has any mentions

        # Check if tweet is a RT, if it is, convert source into a connection if user is not already following
        if p.retweeted_status
          cfollow = Connection.find_by_twitter_id_and_user_id_and_connection_type(p.retweeted_status.user.id, user.id, "following")
          # if mention is not already a source, create a connection
          if cfollow
            cfollow.appearances = cfollow.appearances.to_i+1
            cfollow.save
          else
            m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
            m.average_word_score = (m.average_word_score.to_f+totaltweetscore.to_f)/2
            m.appearances = m.appearances+1
            m.save
          end
        end

        # Check if tweet is in reply to another tweet and check if user follows the soruce of the tweet that is being responded to
        if p.in_reply_to_screen_name
          cfollow = Connection.find_by_twitter_id_and_user_id_and_connection_type(p.in_reply_to_user_id, user.id, "following")
          # if mention is not already a source, create a connection
          if cfollow
            cfollow.appearances = cfollow.appearances.to_i+1
            cfollow.save
          else
            m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
            m.average_word_score = (m.average_word_score.to_f+totaltweetscore.to_f)/2
            m.appearances = m.appearances+1
            m.save
          end
        end

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
        c.average_word_score = (c.average_word_score.to_f+totaltweetscore.to_f)/2
        c.total_tweets_seen = c.total_tweets_seen.to_f+1
        c.overall_index = c.average_word_score.to_f/c.total_tweets_seen.to_f
        
        if totaltweetscore.to_f > c.tone_score.to_f
          c.tone_score = totaltweetscore.to_f
          c.tone_tweet_id = p.id
        elsif totaltweetscore.to_f > c.ttwo_score.to_f
          c.ttwo_score = totaltweetscore.to_f
          c.ttwo_tweet_id = p.id
        elsif totaltweetscore.to_f > c.tthree_score.to_f
          c.tthree_score = totaltweetscore.to_f
          c.tthree_tweet_id = p.id
        end
        
        # calculate connection's tweets per hour
        ageinhours = ((Time.now-p.user.created_at)/60)/60
        c.tweets_per_hour = p.user.statuses_count.to_f/ageinhours.to_f
        c.save
        
        # Update user's and connection's count of tweets shown
		    user.num_tweets_shown = user.num_tweets_shown.to_i+1
		    user.last_wordscore = Time.now
    	  user.save
    	  
    	end # end loop through 800 tweets
    	
    	@mentions = Connection.find(:all, :conditions => ["user_id = ? and connection_type = ?", user.id, "mentioned"], :order => "last_stream_score ASC")
    	i = 0
    	for mention in @mentions
    	  dups = Connection.count(:conditions => ["user_id = ? and connection_type = ? and user_screen_name = ?", user.id, "following", mention.user_screen_name])
    	  if dups > 1
    	    mention.destroy
    	  else
    	    if i < 26
      	    avgconwordscore = 0
      	    if mention.since_tweet_id == 0
      	      @tweets = Twitter.user_timeline(mention.user_screen_name.to_s, :count => 1000)
      	    else
      	      @tweets = Twitter.user_timeline(mention.user_screen_name.to_s, :count => 1000, :since_id => mention.since_tweet_id)
      	    end
        	  @tweets.each do |p|
        	    ctotaltweetscore = 0
        	    @words =  p.full_text.split(" ")
          		# begin looping through words in tweet
          		@words.each do |w|
                # normalize word and look to see if word already exists, if not, create a new one using cleanword above
          			cleanword = w.gsub(/[^0-9a-z]/i, '')
          			cleanword = cleanword.downcase
          			word = Word.find(:first, :conditions => ["word = ? and user_id = ?", cleanword, user.id])
          			if word
          			  if word.sys_ignore_flag == "no"
                    ctotaltweetscore = ctotaltweetscore.to_f+word.score.to_f
          				end # end check if word is on the system ignore list
          			end # end check if user has seen word
          		end # end loop through words
          		mention.average_stream_word_score = (connection.average_stream_word_score.to_f+ctotaltweetscore.to_f)/2
          	  mention.save
          	  if p.id.to_i > mention.since_tweet_id.to_i
      			    mention.since_tweet_id = p.id.to_i
      			    mention.save
          	  end
        	  end # end loop through tweets for scoring connection against user's words
            mention.last_stream_score = Time.now
            mention.save
            i = i + 1
          end
    	  end
    	end
    	
    end # end check to make sure user has upped at least 5 words before continuning to grab tweets
  end # end check user's intial_learning_complete_flag status
  
  user.active_scoring_flag = "no"
  user.save
  
end # End loop through users