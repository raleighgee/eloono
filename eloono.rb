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
  redirect '/tweets'
end

["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
  get path do
    redirect '/auth/twitter'
  end
end

########## MVC CODE ########## 
get '/' do
  %{<a href="http://eloono.com/signin">Click Here to Sign In<a/>}
end

get '/tweets' do

  user = User.find_by_id(session[:user_id])
  
  if user
    
    # Authenticate user for pulling of Tweets
  	Twitter.configure do |config|
  		config.consumer_key = "DHBxwGvab2sJGw3XhsEmA"
  		config.consumer_secret = "530TCO6YMRuB23R7wse91rTcIKFPKQaxFQNVhfnk"
  		config.oauth_token = user.token
  		config.oauth_token_secret = user.secret
  	end
  	
  	# Pull initial information about the user and load all of the people they follow into the sources table if this is the first time we've hit this user
  	if user.num_tweets_shown < 1
      u = Twitter.user(user.uid)
  		user.handle = u.screen_name
  		user.profile_image_url = u.profile_image_url
  		user.language = u.lang.to_s
  		user.save
  		#@tweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true)
  	else
  	  #@tweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true, :since_id => user.latest_tweet_id.to_i )
  	end
  	
  	# declare tweet code variable
    @tweetcode = ""

    # loop through Tweets pulled
    @tweets.each do |p|

      # Check if tweet was created by current user
    	unless p.user.id == user.uid

    	  # set user latest tweet
    	  if p.id.to_i > user.latest_tweet_id.to_i
    	    user.latest_tweet_id = p.id.to_i
    	    user.save
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
      							# increment the number of times word has been seen counter by 1
      							word.seen_count = word.seen_count.to_i+1
      							word.save
      							user.num_words_scored = user.num_words_scored+1
    							end # end check if word is on the system ignore list
    						end # End check if word is empty
    					end # End check if word is just a number
    				end # End check if word contains the @ symbol
    			end # End check if word is a link
    		end # end loop through words  

    	end # end check if tweet was created by user  
    end # end loop through tweets
  	
		@atweets = Twitter.home_timeline(:count => 50, :include_entities => true, :include_rts => true)
		@atweets.each do |p|
		  # Check if tweet was created by current user
    	unless p.user.id == user.uid
		    #### CREATE WORDS AND BUILD OUT CLEAN TWEETS FOR DISPLAY ####
        @words =  p.full_text.split(" ")
        
        # reset cleantweet variable instance
        cleantweet = ""
        # begin looping through words in tweetto build clean tweet
        @words.each do |w|
          
          findword = w.gsub(/[^0-9a-z]/i, '')
          findword = findword.downcase
          
          # calcualte background opacity
          wordscore = Word.find(:first, :conditions => ["user_id = ? and word = ?", user.id, findword])
          if wordscore
            score = wordscore.score
            if score.to_f <= user.firstq_word_score
              wscore = "#ADD5F7"
            elsif score.to_f <= user.avg_word_score
              wscore = "#7FB2F0"
            elsif score.to_f <= user.thirdq_word_score
              wscore = "#4E7AC7"
            else
              wscore = "#16193B"
            end
          else
            wscore = "#CCCCCC"
          end
          
          # Loop through words to create wording for links
          followwords = ""
          @words.each do |w|
            # remove any non alphanumeric charactes from word
          	cleanword = w.gsub(/[^0-9a-z]/i, '')
          	cleanword = cleanword.downcase
            followwords = followwords.to_s+"-"+cleanword.to_s
          end # end loop through words          
          
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
        					cleantweet = cleantweet.to_s+%{<span style="color:}+wscore.to_s+%{;">}+w.to_s+"</span> "
        				end
        			else
        				cleantweet = cleantweet.to_s+%{<span style="color:}+wscore.to_s+%{;">}+w.to_s+"</span> "
        			end
        		elsif w.include? %{#}
        			firstchar = w[0,1]
        			secondchar = [1,1]
        			if firstchar == %{#} or secondchar == %{#}
        				nohandle = w.gsub('#', '')
        				cleantweet = cleantweet.to_s+%{<a href="https://twitter.com/search/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
        			else
        				cleantweet = cleantweet.to_s+%{<span style="color:}+wscore.to_s+%{;">}+w.to_s+"</span> "
        			end
        		else
        			cleantweet = cleantweet.to_s+%{<span style="color:}+wscore.to_s+%{;">}+w.to_s+"</span> "
        		end
        	end # End check if tweet is smaller than 3 words
        end # End create clean tweet
        @tweetcode = @tweetcode.to_s+cleantweet.to_s+%{<br /><br />} 		
  		end # end check if tweet was created by user  
  	end # end loop through tweets
  	

  	
  	# Update user's word scoring ranges and last interaction time
  	user.last_interaction = Time.now
  	user.save
    
    erb :tweets
    
  else
    redirect %{http://eloono.com}
  end # end check if a user exists in the session
  
end

get '/follow' do
  
  link = params[:l]
  fwords = params[:w]
  @words = fwords.split("-")
  @words.each do |w|
    word = Word.find(:first, :conditions => ["word = ? and user_id = ?", w, params[:u]])
    if word
      word.follows = word.follows.to_i+1
      word.save
    end # End check if word is exists
  end # End loop through words			
	
	redirect link
	
end