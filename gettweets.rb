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
	if user.num_tweets_shown < 1
    u = Twitter.user(user.uid)
		user.handle = u.screen_name
		user.profile_image_url = u.profile_image_url
		user.language = u.lang.to_s
		user.save
	end
	
	@tweets = Twitter.home_timeline(:count => 200, :include_entities => true, :include_rts => true, :since_id => user.latest_tweet_id.to_i )
	
	# declare tweet code variable
  @tweetcode = ""
	
	 # loop through Tweets pulled
  @tweets.each do |p|

    # Check if tweet was created by current user
  	unless p.user.id == user.uid

  	  # set user latest tweet
  	  if p.id.to_i > user.latest_tweet_id.to_i
  	    user.latest_tweet_id = p.id.to_i
  	  end

  		# Update user's and connection's count of tweets shown
  	  user.num_tweets_shown = user.num_tweets_shown.to_i+1
  		user.save

  		# Reset total tweet score
  		totaltweetscore = 0
      followwords = ""

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
                    word.score = word.seen_count*(word.follows+1)
                  else
                    word.score = word.seen_count
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
	
	    # reset cleantweet variable instance
      cleantweet = ""
      tscore = "#CCCCCC"
      
      @words.each do |w|
        
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
      					cleantweet = cleantweet.to_s+w.to_s+%{ }
      				end
      			else
      				cleantweet = cleantweet.to_s+w.to_s+%{ }
      			end
      		elsif w.include? %{#}
      			firstchar = w[0,1]
      			secondchar = [1,1]
      			if firstchar == %{#} or secondchar == %{#}
      				nohandle = w.gsub('#', '')
      				cleantweet = cleantweet.to_s+%{<a href="https://twitter.com/search/}+nohandle.to_s+%{" target="_blank">}+w.to_s+%{</a> }
      			else
      				cleantweet = cleantweet.to_s+w.to_s+%{ }
      			end
      		else
      			cleantweet = cleantweet.to_s+w.to_s+%{ }
      		end
      	end # End check if tweet is smaller than 3 words
      	
      	# Update user's tweet scoring ranges
      	if totaltweetscore > user.max_word_score
      	  user.max_word_score = totaltweetscore
      	elsif totaltweetscore < user.min_word_score
      	  user.min_word_score = totaltweetscore
      	end
      	user.avg_word_score = (user.avg_word_score.to_f+totaltweetscore.to_f)/2
      	user.firstq_word_score = (user.min_word_score.to_f+user.avg_word_score.to_f)/2
        user.thirdq_word_score = (user.max_word_score.to_f+user.avg_word_score.to_f)/2
      	user.save
      	
    	  # calcualte background opacity
        if totaltweetscore.to_f <= user.firstq_word_score
          tscore = "tscore_four"
        elsif totaltweetscore.to_f <= user.avg_word_score
          tscore = "tscore_three"
        elsif totaltweetscore.to_f <= user.thirdq_word_score
          tscore = "tscore_two"
        else
          tscore = "tscore_one"
        end

      end # End loop through words to create clean tweet
      
      cleantweet = %{<div class="}+tscore.to_s+%{ tweet_container"><b>}+tscore.to_s+%{<b> | }+cleantweet.to_s+%{</div>}

      @tweetcode = @tweetcode.to_s+cleantweet.to_s+%{<br /><br />}
  	end # end check if tweet was created by user  
  end # end loop through tweets
  
  # Update user's last interaction time
  user.last_tweets = @tweetcode.to_s+user.last_tweets.to_s
  
  if user.last_interaction <= (Time.now)#-(2*60*60))
  
    body = %{<style>a{color:#999999; text-decoration:none;} a:hover;{color:#000000; text-decoration:underline;} .tweet_container{width:100%;} .tscore_one{color:#888888;} .tscore_two{color:#1A1F2B;} .tscore_three{color:#85A5CC;} .tscore_four{color:#85A5CC;}</style>}+user.last_tweets.to_s
  
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
     
  end
    
  user.last_interaction = Time.now
  user.save
  
end # End loop through users