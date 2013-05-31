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
require_relative "./models/source"
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
	if user.num_tweets_shown == 0
    u = Twitter.user(user.uid)
		user.handle = u.screen_name
		user.profile_image_url = u.profile_image_url
		user.language = u.lang.to_s
		user.save
		@tweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true)
		aid = @tweets.size.to_i-1
		@atweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :max_id => @tweets[aid].id.to_i)
		bid = @tweets.size.to_i-1
		@btweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :max_id => @tweets[bid].id.to_i)
		cid = @tweets.size.to_i-1
		@ctweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :max_id => @tweets[cid].id.to_i)
		did = @tweets.size.to_i-1
		@dtweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :max_id => @tweets[did].id.to_i)
		
		@atweets.each do |p|
	    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
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
		end # end loop through atweets
		@btweets.each do |p|
	    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
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
		end # end loop through btweets
		@ctweets.each do |p|
	    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
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
		end # end loop through ctweets
		@dtweets.each do |p|
	    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
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
		end # end loop through dtweets
		
		# Clean out words once user gets to 3000
		wordcount = Word.count(:conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
		if wordcount > 3000
		  wordlimit = wordcount.to_i-3000
		  @killwords = Word.find(:all, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"], :order => "score ASC", :limit => wordlimit)
		  for killword in @killwords
		   killword.destroy
		  end
		end
    
	else
	  @tweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :since_id => user.latest_tweet_id.to_i)
	end
	
	# Reset aggregate level variables
	@tweetcode = ""
	maxtweetwordincrement = 1
	
	# loop through Tweets pulled
	@tweets.each do |p|
	  
	  # Reset variables
	  totaltweetscore = 0
    followwords = ""
    cleantweet = ""
    wscore = "#CCCCCC"
    tscore = 0
    thirdqtoptweetwordscore = 0
    maxtoptweetwordscore = 0
    avgtoptweetwordscore = 0
    maxtweetword = 0

    # Check if tweet was created by current user
  	unless p.user.id == user.uid
      
      if p.full_text.include? %{http}
      
  	    # set user latest tweet
    	  if p.id.to_i > user.latest_tweet_id.to_i
			    user.latest_tweet_id = p.id.to_i
    	  end

    	  # Update user's and connection's count of tweets shown
		    user.num_tweets_shown = user.num_tweets_shown.to_i+1
    	  user.save

        #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
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
      							if word.follows > 0 
								  word.score = word.seen_count*(word.follows.to_f+1)
								else
								  word.score = word.seen_count
								end
								if word.thumb_status == "up"
								  word.score = word.score.to_f*2
								end
								if word.thumb_status == "down"
								  word.score = word.score.to_f/2
								end
      							word.save
      							totaltweetscore = totaltweetscore+word.score
      							user.num_words_scored = user.num_words_scored+1
    							end # end check if word is on the system ignore list
    						end # End check if word is empty
    					end # End check if word is just a number
    				end # End check if word contains the @ symbol
    			end # End check if word is a link

    			#create wording for links
    			cleanword = w.gsub(/[^0-9a-z]/i, '')
        	cleanword = cleanword.downcase
          followwords = followwords.to_s+"-"+cleanword.to_s
                  
    		end # end loop through words
  		
    		# Set tweet class based on aggregate Tweet score
        if totaltweetscore.to_f > user.max_tweet_score.to_f
          user.max_tweet_score = totaltweetscore.to_f
        end
        if totaltweetscore.to_f < user.min_tweet_score.to_f
          user.min_tweet_score = totaltweetscore.to_f
        end
        user.avg_tweet_score = (user.avg_tweet_score.to_f+totaltweetscore.to_f)/2
        user.firstq_tweet_score = (user.avg_tweet_score.to_f+user.min_tweet_score.to_f)/2
        user.thirdq_tweet_score = (user.avg_tweet_score.to_f+user.max_tweet_score.to_f)/2
        user.save
	      
        # Update user's tweet scoring ranges
      	user.max_word_score = Word.maximum(:score, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
      	user.min_word_score = Word.minimum(:score, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
      	user.avg_word_score = Word.average(:score, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
      	user.firstq_word_score = (user.min_word_score.to_f+user.avg_word_score.to_f)/2
        user.thirdq_word_score = (user.max_word_score.to_f+user.avg_word_score.to_f)/2
      	user.save
      
        # Check if tweets is in top tier and only create tweets that are
        if totaltweetscore.to_f >= ((((user.avg_word_score.to_f+user.thirdq_word_score.to_f)/2)+user.thirdq_word_score.to_f)/2)
          @words.each do |w|
        
            #set class based on word score
            cleanword = w.gsub(/[^0-9a-z]/i, '')
            cleanword = cleanword.downcase
            word = Word.find(:first, :conditions => ["word = ? and user_id = ? and sys_ignore_flag = ?", cleanword, user.id, "no"])
            if word
              if word.score.to_f >= ((user.avg_word_score.to_f+user.thirdq_word_score.to_f)/2)
                wscore = "wscore_hot"
              elsif word.score.to_f > maxtweetword.to_f
                maxtweetwordincrement = maxtweetwordincrement.to_i+1
                wscore = "wscore_"+maxtweetwordincrement.to_s
                maxtweetword = word.score.to_f
              else
                wscore = "wscore_four"
              end
              tscore = (tscore.to_f+word.score.to_f)/2          
            else
              wscore = "wscore_four"
            end
        
            # if the number of words in the tweet is less than 3, set the tweet content to exactly what the tweet says - no clean required
          	if @words.size < 3
          		cleantweet = p.full_text
          	else
          		# build clean version of tweet
          		if w.include? %{http}
          			cleantweet = cleantweet.to_s+%{<a href="http://eloono.com/follow?l=}+w.to_s+%{&w=}+followwords.to_s+%{&u=}+user.id.to_s+%{" target="_blank" title="}+w.to_s+%{">[...]</a> }
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
          					cleantweet = cleantweet.to_s+%{<a href="http://twitter.com/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
          				else
          					cleantweet = cleantweet.to_s+%{<span class="}+wscore.to_s+%{">}+w.to_s+%{</span> }
          				end
          			else
          				cleantweet = cleantweet.to_s+%{<span class="}+wscore.to_s+%{">}+w.to_s+%{</span> }
          			end
          		elsif w.include? %{#}
          			firstchar = w[0,1]
          			secondchar = [1,1]
          			if firstchar == %{#} or secondchar == %{#}
          				nohandle = w.gsub('#', '')
          				cleantweet = cleantweet.to_s+%{<a href="https://twitter.com/search/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
          			else
          				cleantweet = cleantweet.to_s+%{<span class="}+wscore.to_s+%{">}+w.to_s+%{</span> }
          			end
          		else
          			cleantweet = cleantweet.to_s+%{<span class="}+wscore.to_s+%{">}+w.to_s+%{</span> }
          		end
          	end # End check if tweet is smaller than 3 words

          end # End loop through words to create clean tweet
        
          if tscore.to_f > maxtoptweetwordscore.to_f
            maxtoptweetwordscore = tscore
          end
          avgtoptweetwordscore = (avgtoptweetwordscore.to_f+tscore.to_f)/2
          thirdqtoptweetwordscore = (maxtoptweetwordscore.to_f+avgtoptweetwordscore.to_f)/2
            
          cleantweet = %{<img src="}+p.user.profile_image_url.to_s+%{" height="24" width="24" style="float:left;" /> }+tscore.round(2).to_s+%{ | }+cleantweet.to_s

          @tweetcode = @tweetcode.to_s+cleantweet.to_s+%{<br /><br />}
        
        end # End check if tweet is in top tier of tweets so far
      
        # Parse through mentions in tweet and create any connections
        @connections = p.user_mentions
        if @connections.size > 0
        	for connection in @connections
        		cfollow = Connection.find_by_twitter_id_and_user_id(connection.id, user.id)
        		# if mention is not already a source, create a connection
        		unless cfollow
        			m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
        			m.average_word_score = (m.average_word_score.to_f+tscore.to_f)/2
        			m.appearances = m.appearances+1
        			m.save
        		end
        	end # End loop through mentions in tweet
        	# 
        	# 
        end # End check tweet has any mentions

        # Check if tweet is a RT, if it is, convert source into a connection if user is not already following
        if p.retweeted_status
        	cfollow = Connection.find_by_twitter_id_and_user_id(p.retweeted_status.user.id, user.id)
        	# if mention is not already a source, create a connection
        	unless cfollow
        		m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
        		m.average_word_score = (m.average_word_score.to_f+tscore.to_f)/2
      			m.appearances = m.appearances+1
      			m.save
        	end
        end

        # Check if tweet is in reply to another tweet and check if user follows the soruce of the tweet that is being responded to
        if p.in_reply_to_screen_name
        	cfollow = Connection.find_by_twitter_id_and_user_id(p.in_reply_to_user_id, user.id)
        	# if mention is not already a source, create a connection
        	unless cfollow
        		m = Connection.find_or_create_by_user_screen_name_and_user_id(:user_screen_name => connection.screen_name, :user_id => user.id, :connection_type => "mentioned")
        		m.average_word_score = (m.average_word_score.to_f+tscore.to_f)/2
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

        # calculate connection's tweets per hour
        ageinhours = ((Time.now-p.user.created_at)/60)/60
        c.tweets_per_hour = p.user.statuses_count.to_f/ageinhours.to_f
        c.total_tweets_seen = c.total_tweets_seen.to_f+1
        c.save
    
      end # end check to see if tweet contained a link
  	end # end check if tweet was created by user  
  end # end loop through tweets
  
  # Update user's last interaction time
  user.last_tweets = @tweetcode.to_s+user.last_tweets.to_s
  user.last_wordscore = Time.now
  user.save
 
  ###### SEND TWEETS EMAIL - BI-DAILY ######## 
  if user.last_tweetemail <= (Time.now-(6*60*60))
        
    body = %{<style>
     body{font-weight:200; color:#CCCCCC;}
     a{color:#CCCCCC; text-decoration:none;}
     .wscore_}+maxtweetwordincrement.to_s+%{{color:#5979CD; font-weight:bold;}
     .wscore_hot{font-size:1.8em; color:#FF0000; font-weight:900;}
     .tscore_one{font-weight:bold; color:#600000;}
     </style>}+user.last_tweets.to_s

    Pony.mail(
      :headers => {'Content-Type' => 'text/html'},
      :from => 'toptweets@eloono.com',
      :to => 'raleigh.gresham@gmail.com',
      :subject => 'Your Color Coded Tweets from the Last Few Hours',
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

    user.last_tweets = ""
    user.save

    # Clean out words once user gets to 3000
    wordcount = Word.count(:conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"])
    if wordcount > 3000
      wordlimit = wordcount.to_i-3000
      @killwords = Word.find(:all, :conditions => ["user_id = ? and sys_ignore_flag = ?", user.id, "no"], :order => "score ASC", :limit => wordlimit)
      for killword in @killwords
       killword.destroy
      end
    end

    # Clean out connections once user gets to 3000
    concount = Connection.count(:conditions => ["user_id = ? and connection_type <> ?", user.id, "following"])
    if concount > 3000
      conlimit = concount.to_i-3000
      @killcons = Connection.find(:all, :conditions => ["user_id = ? and connection_type <> ?", user.id, "following"], :order => "times_in_top ASC, appearances ASC, average_stream_word_score ASC, average_word_score ASC", :limit => conlimit)
      for killcon in @killcons
       killcon.destroy
      end
    end
    
    # Clen out duplicate connections
    @connections = Connection.find(:all, :conditions => ["user_id = ? and connection_type = ?", user.id, "following"])
    for connection in @connections
      @dupcons = Connection.find(:all, :conditions => ["user_screen_name = ? and user_id = ? and connection_type <> ?", connection.user_screen_name, user.id, "following"])
      for dupcon in @dupcons
        dupcon.destroy
      end
    end
    
    user.last_tweetemail = Time.now
    user.save
    
  end # end check if last tweet email sent was at least 12 hours ago
  
  
  
  ###### SCORE CONNECTIONS - DAILY ########
  if user.last_connectionsscore <= (Time.now-(24*60*60))
    # calculate average_stream_word_score for top connections
  	@connections = Connection.find(:all, :conditions => ["user_id = ? and average_stream_word_score = ?", user.id, 0], :order => "average_word_score DESC", :limit => 10)
  	for connection in @connections
  	  avgconwordscore = 0
  	  @tweets = Twitter.user_timeline(connection.user_screen_name.to_s, :count => 200)
  	  @tweets.each do |p|
  	    avgtweetwscore = 0
  	    @words =  p.full_text.split(" ")
    		# begin looping through words in tweet
    		@words.each do |w|
          # normalize word and look to see if word already exists, if not, create a new one using cleanword above
    			cleanword = w.gsub(/[^0-9a-z]/i, '')
    			cleanword = cleanword.downcase
    			word = Word.find(:first, :conditions => ["word = ? and user_id = ?", cleanword, user.id])
    			if word
    			  if word.sys_ignore_flag == "no"
              avgtweetwscore = (avgtweetwscore.to_f+word.score.to_f)/2
              avgconwordscore = (avgconwordscore.to_f+avgtweetwscore.to_f)/2
    				end # end check if word is on the system ignore list
    			end # end check if user has seen word
    		end # end loop through words
  	  end # end loop through tweets for scoring connection against user's words
  	  connection.average_stream_word_score = avgconwordscore.to_f
  	  connection.save
  	end # end loop through top connections
  	
  	@connections = Connection.find(:all, :conditions => ["user_id = ? and times_in_top > ?", user.id, 0], :order => "average_stream_word_score DESC, average_word_score DESC", :limit => 5)
  	for connection in @connections
  	  avgconwordscore = 0
  	  @tweets = Twitter.user_timeline(connection.user_screen_name.to_s, :count => 200)
  	  @tweets.each do |p|
  	    avgtweetwscore = 0
  	    @words =  p.full_text.split(" ")
    		# begin looping through words in tweet
    		@words.each do |w|
          # normalize word and look to see if word already exists, if not, create a new one using cleanword above
    			cleanword = w.gsub(/[^0-9a-z]/i, '')
    			cleanword = cleanword.downcase
    			word = Word.find(:first, :conditions => ["word = ? and user_id = ?", cleanword, user.id])
    			if word
    			  if word.sys_ignore_flag == "no"
              avgtweetwscore = (avgtweetwscore.to_f+word.score.to_f)/2
              avgconwordscore = (avgconwordscore.to_f+avgtweetwscore.to_f)/2
    				end # end check if word is on the system ignore list
    			end # end check if user has seen word
    		end # end loop through words
  	  end # end loop through tweets for scoring connection against user's words
  	  connection.average_stream_word_score = avgconwordscore.to_f
  	  connection.times_in_top = connection.times_in_top.to_f+1
  	  connection.save
  	end # end loop through top connections
  	
  	user.last_connectionsscore = Time.now
    user.save
  	
  end # end check if last word email sent was at least 24 hours ago

  
  
  ###### SEND TOP WORDS EMAIL - 2 DAILY ######
  if user.last_wordemail <= (Time.now-(12*60*60))
    
    #reset email content
    wordcode = ""
    
    @words = Word.find(:first, :conditions => ["user_id = ? and thumb_status = ? and sys_ignore_flag = ? and score > ?", user.id, "neutral", "no", 0], :order => "score DESC")
    for word in @words
      wordcode = wordcode.to_s+word.word.to_s+%{ | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/up" target="_blank">+</a> | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/down" target="_blank">-</a> | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/ignore" target="_blank">x</a> | <a style="font-size:1.2em;" href="http://eloono.com/words/}+word.id.to_s+%{/neutral" target="_blank">o</a><br /><br />}
    end # End loop through words to build email content
    
    body = %{<div style="font-size:1.4em;">}+wordcode.to_s+%{</div>}
    
    Pony.mail(
      :headers => {'Content-Type' => 'text/html'},
      :from => 'topwords@eloono.com',
      :to => 'raleigh.gresham@gmail.com',
      :subject => 'How do these words make you feel?',
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
    
    user.last_wordemail = Time.now
    user.save
    
  end # end check if last connections score was at least 24 hours ago

  ###### SEND CONNECTIONS REC. EMAIL - WEEKLY ######
  if user.last_connectionsemail <= (Time.now-(7*24*60*60))
		body = ""
		@connections = Connection.find(:all, :conditions => ["user_id = ? and connection_type = ?", user.id, "mentioned"], :limit => 5, :order => "average_stream_word_score DESC")
		for connection in @connections
			c = Twitter.user(connection.user_screen_name)
			if c
				connection.twitter_id = c.id
				connection.profile_image_url = c.profile_image_url
				connection.user_name = c.name
				connection.following_flag = c.following
				connection.user_description = c.description
				connection.user_url = c.url
				connection.user_language = c.lang
				connection.location = c.location
				connection.twitter_created_at = c.created_at
				connection.statuses_count = c.statuses_count
				connection.followers_count = c.followers_count
				connection.friends_count = c.friends_count
				connection.connection_type = "reccomended"
				ageinhours = ((Time.now-c.created_at)/60)/60
				connection.tweets_per_hour = c.statuses_count.to_f/ageinhours.to_f
				connection.save
			end # end check if Twitter can find this connection
			
			ageinyears = ((((Time.now-connection.twitter_created_at)/60)/60)/24)/365
  		ftofratio = connection.friends_count.to_f/connection.followers_count.to_f
			if connection.location == ""
			  local = "Unknown"
			else
			  local = connection.location
			end
			
			body = body.to_s+%{<div style="text-align:center;"><h3>}+connection.user_screen_name.to_s+%{</h3><a href="}+connection.user_url.to_s+%{" target="_blank"><img src="}+connection.profile_image_url.to_s+%{" width="48" hegith="48" /></a><p>This is <b>}+connection.user_name.to_s+%{</b> - <i>}+connection.user_description.to_s+%{</i> They speak <b>}+connection.user_language.upcase.to_s+%{</b> and are located in <b>}+local.to_s+%{</b>. They have been on Twitter for <b>}+ageinyears.to_f.round.to_s+%{</b> years and have sent <b>}+connection.statuses_count.to_f.round.to_s+%{</b> tweets at a rate of <b>}+connection.tweets_per_hour.to_f.round(2).to_s+%{</b> tweets per hour. They have <b>}+connection.friends_count.to_f.round.to_s+%{</b> friends and <b>}+connection.followers_count.to_f.round.to_s+%{</b> followers.</p><h5><a href="http://eloono.com/conrec/}+connection.id.to_s+%{/}+user.id.to_s+%{/follow" target="_blank">Follow</a> | <a href="http://eloono.com/conrec/}+connection.id.to_s+%{/}+user.id.to_s+%{/ignore" target="_blank">Ignore</a></h5></div><br />}
			
		end
		
		Pony.mail(
		  :headers => {'Content-Type' => 'text/html'},
		  :from => 'recommendations@eloono.com',
		  :to => 'raleigh.gresham@gmail.com',
		  :subject => 'Some people you might want to connect with.',
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
		
		user.last_connectionsemail = Time.now
		user.save

	
  end # end check if last connections email was at least 7 days ago
    
end # End loop through users