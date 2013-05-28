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
	# award top connections
	@connections = Connection.find(:all, :conditions => ["user_id = ?", user.id], :order_by => "average_stream_word_score DESC, average_word_score DESC, appearances DESC", :limit => 10)
	for connection in @connections
	  avgconwordscore = 0
	  connection.times_in_top = connection.times_in_top+1
	  @tweets = Twitter.user_timeline(connection.user_screen_name.to_s, :count => 200)
	  @tweets.each do |p|
	    avgtweetwscore = 0
	    @words =  p.full_text.split(" ")
  		# begin looping through words in tweet
  		@words.each do |w|
        # normalize word and look to see if word already exists, if not, create a new one using cleanword above
  			cleanword = w.gsub(/[^0-9a-z]/i, '')
  			cleanword = cleanword.downcase
  			word = Word.find_by_word_and_user_id(:word => cleanword, :user_id => user.id)
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
end # end loop through users