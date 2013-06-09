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