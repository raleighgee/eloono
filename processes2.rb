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
	  
    #### SCORE WORDS FOR INTIAL LEARNING ####
    i = 0
    maxid = 0
    begin
      if i == 0 
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
    end while i < 2 # End iterate through intial 8000 tweets		
	end # end check if this is uers's initial pass  
end # End loop through users