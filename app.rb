########## GEM REQUIRES ########## 
require 'rubygems'
require 'sinatra'
require 'active_record'
require 'mysql2'
require 'rake'
require "pony"


########## CONFIG ########## 
enable  :sessions, :logging

########## DATABASE CONNECTIONS ##########
ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "localhost",
  :username => "raleighg_raleigh",
  :password => "r@ls0381",
  :database => "raleighg_engagement"
)

########## MODELS ########## 
class Leader < ActiveRecord::Base
	self.primary_key = 'user_id'
	has_many :tweets
	belongs_to :user
	belongs_to :category
end

class Tweet < ActiveRecord::Base
	self.primary_key = 'tweet_id'
	belongs_to :leader
	has_many :tweeturls
end

class User < ActiveRecord::Base
	self.primary_key = 'user_id'
	has_many :leaders
	belongs_to :category
	has_many :friends
end

class TweetUrl < ActiveRecord::Base
	self.primary_key = "tweet_id"
	belongs_to :tweet
end

class TweetTag < ActiveRecord::Base
	self.primary_key = "tweet_id"
end

class TweetMention < ActiveRecord::Base
	self.primary_key = "tweet_id"
end

class TweetRetweet < ActiveRecord::Base
	self.primary_key = "tweet_id"
end

class Follower < ActiveRecord::Base
	self.primary_key = "user_id"
end

class Friend < ActiveRecord::Base
	self.primary_key = "user_id"
	belongs_to :user
end

class Category < ActiveRecord::Base
	self.primary_key = "id"
	has_many :leaders
	has_many :users
end

########## VIEWS ########## 

get '/' do

	@title = "Eloono"
	@code = ""

	@recs = User.where("eloono_status = ?", "Recommended").order("big_eloono_score DESC").limit(1)
	
	for rec in @recs
		ftofratio = rec.followers_count.to_f/rec.friends_count.to_f
		ftofratio = ftofratio.round(2)
		tperday = rec.statuses_count.to_f/((((Time.now-rec.created_at)/60)/60)/24)
		tperday = tperday.round(2)
		recage = ((((Time.now-rec.created_at)/60)/60)/24)/365
		recage = recage.round(2)
		if recage < 1
			recagetext = "less than a year"
		else
			recagetext = recage.to_s+" years"
		end

		usertype = ""
		if rec.followers_count.to_f > 2500 and rec.friends_count.to_f > 2500 and ftofratio.to_f >= 2
			usertype = "a Marketer (indiscriminate net-worker)"
		elsif rec.friends_count.to_f > 4999 and ftofratio.to_f <= 0.5
			usertype = "a Pinger (they're just following anything that breathes)"
		elsif rec.followers_count.to_f > 4999 and ftofratio.to_f >= 5
			usertype = "a Celebrity (lots of followers, close set of friends)"
		elsif ftofratio.to_f >= 1
			usertype = "an Up and Comer (mentioned and re-tweeted but has a smaller network)"
		else
			usertype = "a 'Hmmmmmm' (not sure what to make of this person)"
		end

		eloonoscore = rec.big_eloono_score.to_i

		@code = @code.to_s + %{<div class="rec_container" id="}+rec.user_id.to_s+%{"><a href="twitter://user?screen_name=}+rec.screen_name.to_s+%{" target="_blank"><img src="}+rec.profile_image_url.to_s+%{" height="33px" width="33px" /> }+rec.name.to_s+%{</a>}

		if rec.location != ""
			@code = @code.to_s+%{ | }+rec.location.to_s
		end

		#@code = @code.to_s+%{ | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/follow/}+rec.id.to_s+%{/direct" recid="}+rec.user_id.to_s+%{" target="_blank">Follow</a> | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/ignore/}+rec.user_id.to_s+%{/na">Ignore</a>}

		@code = @code.to_s+%{<p style="text-align:center; padding-bottom:13px;"><em>}+rec.description.to_s+%{</em></p>}
		
		if rec.url != ""
			@code = @code.to_s+%{<p style="text-align:center; padding-bottom:13px;"><a href="}+rec.url.to_s+%{" target="_blank">}+rec.name.to_s+%{'s URL</a></p>}
		end

		@code = @code.to_s+%{<p style="font-size:0.85em; text-align:left;">Their Eloono Score is }+eloonoscore.to_s+%{. They are likely <b>}+usertype.to_s+%{</b> and have tweeted <b>}+rec.statuses_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse.to_s+%{</b> times at a rate of <b>}+tperday.to_s+%{</b> tweets per day. They have been on Twitter for <b>}+recagetext.to_s+%{</b>.</p><p style="text-align:center; font-size:1.2em;">&larr; Ignore |  Follow &rarr;</p></div>}
	end
	
	erb :tweets
	
end

get '/friend/:id' do
	user = User.find_by_user_id(params[:id])
	@user = User.find_by_user_id(params[:id])
	@title = "Eloono | Tweets from "+user.name.to_s
	@usercode = %{<a class="hidden-lg hidden-md" href="twitter://user?screen_name=}+user.screen_name.to_s+%{" target="_blank"><img style="float:left;" src="}+user.profile_image_url.to_s+%{" width="42" /></a><a class="hidden-xs hidden-sm" href="http://twitter.com/}+user.screen_name.to_s+%{" target="_blank"><img style="float:left;" src="}+user.profile_image_url.to_s+%{" width="42" /></a> <h2 style="margin-top:14px; padding-left:53px;">}+user.name.to_s+%{</h2>}
	
	@categories = Category.where("name <> ?", "New").order(name: :asc)

	@code = ""
	tweetcode = %{<div style="width:80%;">}
	#rtcode =  %{<div style="width:80%;"><h3>Retweets</h3>}
	#linkcode =  %{<div style="width:80%;"><h3>Tweet Links</h3>}
	dayold = Time.now-(60*60*25)
	
	@tweets = Tweet.where("user_id = ? and created_at > ? and eloono_sent_flag <> ?", user.user_id, dayold, "yes").order(tweet_id: :desc)
	#@rttweets = Tweet.where("user_id = ? and is_rt <> ? and created_at > ? and eloono_sent_flag <> ?", user.user_id, "true", dayold, "yes").order(tweet_id: :desc)
	#@ltweets = Tweet.where("user_id = ? and created_at > ? and eloono_sent_flag <> ?", user.user_id, dayold, "yes").order(tweet_id: :desc)

	showfriendt = ""
	if @tweets.size > 0
		num_non_at_tweets = 0
		for tweet in @tweets
			unless tweet.tweet_text.to_s[0,1] == "@" or tweet.tweet_text.to_s[0,1] == "."
				num_non_at_tweets = num_non_at_tweets.to_i+1
			end
		end
		if num_non_at_tweets > 0
			thistweetcode = ""
			for tweet in @tweets
				unless tweet.tweet_text.to_s[0,1] == "@" or tweet.tweet_text.to_s[0,1] == "."
					#unless TweetUrl.exists?(:tweet_id => tweet.tweet_id)
					tcontent = ""
					agetext = (((Time.now.to_f-tweet.created_at.to_f)/60)/60).to_i
					if tweet.tweet_text.include? %{http://} or tweet.tweet_text.include? %{https://}
						values = tweet.tweet_text.split(" ")
						values.each do |value|
							if value.include? %{http://} or value.include? %{https://}
								if TweetUrl.exists?(:tweet_id => tweet.tweet_id)
									tcontent = tcontent.to_s+" "+%{<a class="hidden-lg hidden-md" href="http://eloono.raleighgresham.com/see_tweet/url/}+tweet.tweet_id.to_s+%{/direct" target="_blank"><i class="fa fa-external-link-square"></i></a><a class="hidden-xs hidden-sm" href="http://eloono.raleighgresham.com/see_tweet/url/}+tweet.tweet_id.to_s+%{/web" target="_blank"><i class="fa fa-external-link-square"></i></a>}
								else
									tcontent = tcontent.to_s+" "+%{<i class="fa fa-question-circle"></i></a>}	
								end
							else
					    		tcontent = tcontent.to_s+" "+value.to_s
							end
						end
					else
						tcontent = tweet.tweet_text
					end
					thistweetcode = thistweetcode.to_s+%{<span style="font-size:85%;">}+tcontent.to_s+%{</span><br />}+agetext.to_s+%{ hours old&nbsp;&nbsp;|&nbsp;&nbsp;<a class="hidden-lg hidden-md" href="http://eloono.raleighgresham.com/see_tweet/tweet/}+tweet.tweet_id.to_s+%{/direct" target="_blank">&rarr;</a><a class="hidden-xs hidden-sm" href="http://eloono.raleighgresham.com/see_tweet/tweet/}+tweet.tweet_id.to_s+%{/web" target="_blank">&rarr;</a><br /><br />}
					if tweet.is_rt == "true"
						thistweetcode = %{<i class="fa fa-retweet"></i> }+thistweetcode.to_s
					end
					user.count_tweets = user.count_tweets - 1
					user.save
					showfriendt = "yes"
					#end
				end
			end
		end
		if showfriendt == "yes"
			tweetcode = tweetcode.to_s+thistweetcode.to_s
		end
	end
		
	leader = Leader.find_by_user_id(params[:id])
	leader.eloono_last_touch_ts = Time.now
	leader.save
	
	tweetcode = tweetcode.to_s+%{</div>}
	#rtcode =  rtcode.to_s+%{</div>}
	#linkcode =  linkcode.to_s+%{</div>}
	if showfriendt != "yes"
		tweetcode = ""
	end
		
	@code = @code.to_s+tweetcode.to_s
			
	erb :friend , :layout => false
end

get '/friend_category' do
	@title = "Eloono | Assign a Category"
	@user = User.find_by_user_id(params[:friend])
	
	if params[:type] == "remove"
		# delete tweets, urls, metions, retweets, tags, and leader record
		# if no more leaders in category, then delete category
	end

	if params[:type] == "change"
		@category = Category.find_by_id(params[:newcategory])
	end
	
	erb :friend_category
	
end

get '/needcats' do
	@friends = Friend.all
	@code = ""
	for friend in @friends
		if User.exists?(:user_id => friend.user_id, :friend_flag => "no")
			@code = @code.to_s+%{<img src="}+friend.user.profile_image_url.to_s+%{" style="padding:9px" />}
		end
	end
	
	@code = @code.to_s+%{<br /><br />}
	
	@uncats = User.where("category_name = ? and friend_flag = ?", "Uncategorized", "yes")
	for uncat in @uncats
		@code = @code.to_s+%{<img src="}+uncat.profile_image_url.to_s+%{" style="padding:9px" />}
	end
	
	erb @code, :layout => false
end

########## USER ACTIONS ########## 

post '/assign_new_category/:id/:type' do
	user = User.find_by_user_id(params[:id])
	if params[:type] == "new"
		nextr = Time.now+(60*60*3) + (60*(1+rand(60)))
		lastr = Time.now
		if user.category_name != "Uncategorized"
			newcategory = Category.create!(:name => params[:category], :created_at => Time.now, :updated_at => Time.now, :next_release => nextr, :last_release => lastr)
			user.category_name = newcategory.name
			user.eloono_points = user.eloono_points + 2
			user.last_eloono_points_scored = Time.now
			user.save
			leader = Leader.find_by_user_id(user.user_id)
			oldcat = leader.category_id
			countcat = Leader.count(:conditions => ["category_id = ?", oldcat])
			if countcat < 2
				delcat = Category.find_by_id(leader.category_id)
				delcat.destroy
			end
			leader.category_id = newcategory.id
			leader.save
		else
			newcategory = Category.create!(:name => params[:category], :created_at => Time.now, :updated_at => Time.now, :next_release => nextr, :last_release => lastr)
			user.category_name = newcategory.name
			user.eloono_points = user.eloono_points + 2
			user.last_eloono_points_scored = Time.now
			user.save
			ntweetid = (Tweet.minimum(:tweet_id))-1
			leader = Leader.create!(:user_id => user.user_id, :category_id => newcategory.id, :screen_name => user.screen_name, :old_timeline_collected => Time.now, :old_search_collected => Time.now, :search_since_id => (ntweetid-1))
			ntweet = Tweet.create(:tweet_id => ntweetid, :tweet_text => "ELOONO SEED", :user_id => leader.user_id, :is_rt => 0, :retweet_count => 0, :eloono_sent_flag => "yes", :created_at => Time.now)
		end
		
	end
	
	if params[:type] == "change"
		if user.category_name != "Uncategorized"
			category = Category.find_by_id(params[:category_id])
			user.category_name = category.name
			user.save
			leader = Leader.find_by_user_id(user.user_id)
			leader.category_id = category.id
			leader.save
		else
			category = Category.find_by_id(params[:category_id])
			user.category_name = category.name
			user.save
			ntweetid = (Tweet.minimum(:tweet_id))-1
			leader = Leader.create!(:user_id => user.user_id, :category_id => category.id, :screen_name => user.screen_name, :old_timeline_collected => Time.now, :old_search_collected => Time.now, :search_since_id => (ntweetid-1))
			ntweet = Tweet.create(:tweet_id => ntweetid, :tweet_text => "ELOONO SEED", :user_id => leader.user_id, :is_rt => 0, :retweet_count => 0, :eloono_sent_flag => "yes", :created_at => Time.now)
		end
		countcat = Leader.count(:conditions => ["category_id = ?", leader.category_id])
		if countcat < 2
			delcat = Category.find_by_id(leader.category_id)
			delcat.destroy
		end
	end
	
	if params[:type] == "remove"
		user.category_name = "Uncategorized"
		user.eloono_points = user.eloono_points - 1
		user.last_eloono_points_scored = Time.now
		user.save
		leader = Leader.find_by_user_id(user.user_id)
		countcat = Leader.count(:conditions => ["category_id = ?", leader.category_id])
		if countcat < 2
			delcat = Category.find_by_id(leader.category_id)
			delcat.destroy
		end
		leader.destroy
	end
	
	redirect "http://eloono.raleighgresham.com"
	
end

get '/rec_action/:cat/:type/:id/:screen' do
	rec = User.find_by_user_id(params[:id])
	
	if params[:type] == "ignore"
		rec.eloono_status = "Ignored"
		rec.save
		redirect "http://eloono.raleighgresham.com"
	end
	
	if params[:type] == "follow"
		rec.eloono_status = "Followed"
		rec.category_name = "New"
		rec.save
		ntweetid = (Tweet.minimum(:tweet_id))-1
		leader = Leader.create!(:user_id => rec.user_id, :category_id => 16, :screen_name => rec.screen_name, :old_timeline_collected => Time.now, :old_search_collected => Time.now,  :search_since_id => (ntweetid-1))
		ntweet = Tweet.create(:tweet_id => ntweetid, :tweet_text => "ELOONO SEED", :user_id => leader.user_id, :is_rt => 0, :retweet_count => 0, :eloono_sent_flag => "yes", :created_at => Time.now)
		redirect "twitter://user?screen_name="+rec.screen_name.to_s
		#twitter://user?screen_name=
		#http://twitter.com/
	end
end

get '/mark_tweets_as_seen/:friend' do
	@atweets = Tweet.where("user_id = ? and eloono_sent_flag <> ?", params[:friend], "yes")
	for atweet in @atweets
		atweet.eloono_sent_flag = "yes"
		atweet.save
	end
	
	unless params[:ignore] == "yes"
		user = User.find_by_user_id(params[:friend])
		user.eloono_points = user.eloono_points+1
		user.last_eloono_points_scored = Time.now
		user.save
	end
	
	erb "Done Here"
end

get '/mark_category_as_seen/:category' do

	@users = User.where("category_name = ? and eloono_status = ?", params[:category], "friend")
	for user in @users
		@tweets = Tweet.where("user_id = ? and eloono_sent_flag <> ?", user.user_id, "yes")
		for tweet in @tweets
			tweet.eloono_sent_flag = "yes"
			tweet.save
		end
	end

	erb "Done Here"

end

get '/see_tweet/:type/:tweet/:screen' do 
	tweet = Tweet.find_by_tweet_id(params[:tweet])
	user = User.find_by_user_id(tweet.user_id)
	user.eloono_points = user.eloono_points + 2
	user.last_eloono_points_scored = Time.now
	user.save
	if params[:type] == "url"
		url = TweetUrl.find_by_tweet_id(tweet.tweet_id)
		redirect url.url
	else
		if params[:screen] == "direct"
			redirect "twitter://status?id="+tweet.tweet_id.to_s
		end
		if params[:screen] == "web"
			redirect "http://twitter.com/"+user.screen_name.to_s+"/status/"+tweet.tweet_id.to_s
		end
	end
	
end

########## CRONS ##########

get '/refresh_rec' do #Refresh Every 5 seconds
	@code = ""

	@recs = User.where("eloono_status = ?", "Recommended").order("big_eloono_score DESC").limit(1)
	
	for rec in @recs
		ftofratio = rec.followers_count.to_f/rec.friends_count.to_f
		ftofratio = ftofratio.round(2)
		tperday = rec.statuses_count.to_f/((((Time.now-rec.created_at)/60)/60)/24)
		tperday = tperday.round(2)
		recage = ((((Time.now-rec.created_at)/60)/60)/24)/365
		recage = recage.round(2)
		if recage < 1
			recagetext = "less than a year"
		else
			recagetext = recage.to_s+" years"
		end

		usertype = ""
		if rec.followers_count.to_f > 2500 and rec.friends_count.to_f > 2500 and ftofratio.to_f >= 2
			usertype = "a Marketer (indiscriminate net-worker)"
		elsif rec.friends_count.to_f > 4999 and ftofratio.to_f <= 0.5
			usertype = "a Pinger (they're just following anything that breathes)"
		elsif rec.followers_count.to_f > 4999 and ftofratio.to_f >= 5
			usertype = "a Celebrity (lots of followers, close set of friends)"
		elsif ftofratio.to_f >= 1
			usertype = "an Up and Comer (mentioned and re-tweeted but has a smaller network)"
		else
			usertype = "a 'Hmmmmmm' (not sure what to make of this person)"
		end

		eloonoscore = rec.big_eloono_score.to_i

		@code = @code.to_s + %{<div class="rec_container" id="}+rec.user_id.to_s+%{"><a href="twitter://user?screen_name=}+rec.screen_name.to_s+%{" target="_blank"><img src="}+rec.profile_image_url.to_s+%{" height="33px" width="33px" /> }+rec.name.to_s+%{</a>}

		if rec.location != ""
			@code = @code.to_s+%{ | }+rec.location.to_s
		end

		#@code = @code.to_s+%{ | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/follow/}+rec.id.to_s+%{/direct" recid="}+rec.user_id.to_s+%{" target="_blank">Follow</a> | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/ignore/}+rec.user_id.to_s+%{/na">Ignore</a>}

		@code = @code.to_s+%{<p style="text-align:center; padding-bottom:13px;"><em>}+rec.description.to_s+%{</em></p>}
		
		if rec.url != ""
			@code = @code.to_s+%{<p style="text-align:center; padding-bottom:13px;"><a href="}+rec.url.to_s+%{" target="_blank">}+rec.name.to_s+%{'s URL</a></p>}
		end

		@code = @code.to_s+%{<p style="font-size:0.85em; text-align:left;">Their Eloono Score is }+eloonoscore.to_s+%{. They are likely <b>}+usertype.to_s+%{</b> and have tweeted <b>}+rec.statuses_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse.to_s+%{</b> times at a rate of <b>}+tperday.to_s+%{</b> tweets per day. They have been on Twitter for <b>}+recagetext.to_s+%{</b>.</p><p style="text-align:center; font-size:1.2em;">&larr; Ignore |  Follow &rarr;</p></div><script>$(".rec_container").swipe({swipe:function(event, direction, distance, duration, fingerCount){var recId = $(this).attr('id');if (direction == "right"){window.location.href = "http://eloono.raleighgresham.com/rec_action/none/follow/"+recId+"/direct";} else if (direction == "left") {$('.rec_refresh_container').html("");window.location.href = "http://eloono.raleighgresham.com/rec_action/none/ignore/"+recId+"/na";};}});</script>}
	end

	erb @code, :layout => false

end

get '/count_activity' do # Hourly

	@retweets = TweetRetweet.where("eloono_counted_flag <> ?", "yes")
	@mentions = TweetMention.where("eloono_counted_flag <> ?", "yes")
	for retweet in @retweets
		sourceuser = User.find_by_user_id(retweet.source_user_id)
		if sourceuser
			retweet.source_category_name = sourceuser.category_name
			retweet.save
		end
		targetuser = User.find_by_user_id(retweet.target_user_id)
		if targetuser
			retweet.target_category_name = targetuser.category_name
			retweet.save
			unless Friend.exists?(:user_id => retweet.target_user_id)
				unless Follower.exists?(:user_id => retweet.target_user_id)
					targetuser.count_retweets = targetuser.count_retweets.to_i + 1
					targetuser.total_interactions = targetuser.total_interactions.to_i + 1
					@rtappears = TweetRetweet.where("target_user_id = ? and source_category_name <> ? and source_category_name <> ? and source_category_name <> ? and source_user_id <> ?", retweet.target_user_id, "Uncategorized", "0", "", "280795938" ).group(:source_category_name)
					if @rtappears.length > 0 
						targetuser.num_appear = @rtappears.length
						targetuser.save
					end
					if sourceuser
						if (targetuser.eloono_rec_score + sourceuser.eloono_points) <= 0
							targetuser.eloono_rec_score = 0
						else
							targetuser.eloono_rec_score = (targetuser.eloono_rec_score + sourceuser.eloono_points)/2
						end
						targetuser.save
					end
				end
			end
		end
		retweet.eloono_counted_flag = "yes"
		retweet.save
	end
	
	for mention in @mentions
		sourceuser = User.find_by_user_id(mention.source_user_id)
		if sourceuser
			mention.source_category_name = sourceuser.category_name
			mention.save
		end
		targetuser = User.find_by_user_id(mention.target_user_id)
		if targetuser
			mention.target_category_name = targetuser.category_name
			mention.save
			unless Friend.exists?(:user_id => mention.target_user_id)
				unless Follower.exists?(:user_id => mention.target_user_id)
					targetuser.count_retweets = targetuser.count_retweets.to_i + 1
					targetuser.total_interactions = targetuser.total_interactions.to_i + 1
					@mtappears = TweetMention.where("target_user_id = ? and source_category_name <> ? and source_category_name <> ? and source_category_name <> ? and source_user_id <> ?", mention.target_user_id, "Uncategorized", "0", "", "280795938" ).group(:source_category_name)
					if @mtappears.length > 0
						targetuser.num_appear = targetuser.num_appear + @mtappears.length
						targetuser.save
					end
					if sourceuser
						if (targetuser.eloono_rec_score + sourceuser.eloono_points) <= 0
							targetuser.eloono_rec_score = 0
						else
							targetuser.eloono_rec_score = (targetuser.eloono_rec_score + sourceuser.eloono_points)/2
						end
						targetuser.save
					end
				end
			end
		end
		mention.eloono_counted_flag = "yes"
		mention.save
	end

	avgappears = User.where("eloono_rec_score > ? and num_appear > ? and total_interactions > ? and friend_flag = ?", 0, 0, 0, "no").average(:num_appear)
	avginteractions = User.where("eloono_rec_score > ? and num_appear > ? and total_interactions > ? and friend_flag = ?", 0, 0, 0, "no").average(:total_interactions)
	avgrecscore = User.where("eloono_rec_score > ? and num_appear > ? and total_interactions > ? and friend_flag = ?", 0, 0, 0, "no").average(:eloono_rec_score)

	@recs = User.where("eloono_rec_score > ? and num_appear > ? and total_interactions > ? and friend_flag = ? and eloono_status <> ? and eloono_status <> ?", 0, 0, 0, "no", "Ignored", "Followed")
	for rec in @recs
		if rec.eloono_rec_score > avgrecscore and rec.total_interactions > avginteractions and rec.num_appear > avgappears
			rec.eloono_status = "Recommended"
			rec.big_eloono_score = ((rec.eloono_rec_score.to_f + rec.total_interactions.to_f + rec.num_appear.to_f)/3)
			rec.save
		end
	end

	@friends = Friend.all
	for friend in @friends
		@leaders = Leader.where("user_id = ? ", friend.user_id)
		if @leaders.size < 1
			user = User.find_by_user_id(friend.user_id)
			ntweetid = (Tweet.minimum(:tweet_id))-1
			nleader = Leader.create!(:user_id => user.user_id, :category_id => 16, :screen_name => user.screen_name, :old_timeline_collected => Time.now, :old_search_collected => Time.now,  :search_since_id => (ntweetid-1))
			ntweet = Tweet.create(:tweet_id => ntweetid, :tweet_text => "ELOONO SEED", :user_id => user.user_id, :is_rt => 0, :retweet_count => 0, :eloono_sent_flag => "yes", :created_at => Time.now)
		end
	end
		
	erb "Done Here"

end

get '/hourly_clean_up' do # twice an hour
	@friends = Friend.all
	for friend in @friends
		user = User.find_by_user_id_and_friend_flag(friend.user_id, "no")
		if user
			@mentions = TweetMention.where("target_user_id = ? and eloono_counted_flag = ?", user.user_id, "yes")
			for mention in @mentions
				sourceuser = User.where("user_id = ?", mention.source_user_id)
				sourceuser.eloono_points = sourceuser.eloono_points+1
				sourceuser.save
			end
			@retweets = TweetRetweet.where("target_user_id = ? and eloono_counted_flag = ?", user.user_id, "yes")
			for retweet in @retweets
				sourceuser = User.where("user_id = ?", retweet.source_user_id)
				sourceuser.eloono_points = sourceuser.eloono_points+1
				sourceuser.save
			end
			user.friend_flag = "yes"
			user.eloono_status = "friend"
			user.save
		end
	end
	
	@leaders = Leader.all
	for leader in @leaders
		unless Friend.exists?(:user_id => leader.user_id)
			leader.destroy
		end
		unless Tweet.exists?(:user_id => leader.user_id)
			ntweetid = (Tweet.minimum(:tweet_id))-1
			ntweet = Tweet.create(:tweet_id => ntweetid, :tweet_text => "ELOONO SEED", :user_id => leader.user_id, :is_rt => 0, :retweet_count => 0, :eloono_sent_flag => "yes", :created_at => Time.now)
		end
		if leader.search_since_id == 0
			ntweetid = (Tweet.minimum(:tweet_id))-1
			leader.search_since_id = (ntweetid)
			leader.save
		end
	end

	@leaders = Leader.where("old_timeline_collected = ? or old_search_collected = ?", "0000-00-00 00:00:00", "0000-00-00 00:00:00")
	for leader in @leaders
		leader.old_timeline_collected = Time.now
		leader.old_search_collected = Time.now
		leader.save
	end
	
	erb "Done Here"

end

get '/weekly_clean_up' do
	
	weekold = Time.now - (60*60*25*7)
	@oldtweets = Tweet.where("created_at < ? and tweet_text <> ?", weekold, "ELOONO SEED")
	for oldtweet in @oldtweets
		@oldurls = TweetUrl.where("tweet_id = ?", oldtweet.tweet_id)
		for oldurl in @oldurls
			oldurl.destroy
		end
		@oldtags = TweetTag.where("tweet_id = ?", oldtweet.tweet_id)
		for oldtag in @oldtags
			oldtag.destroy
		end
		oldtweet.destroy
	end
	@seentweets = Tweet.where("eloono_sent_flag = ? and tweet_text <> ?", "yes", "ELOONO SEED")
	for seentweet in @seentweets
		@oldurls = TweetUrl.where("tweet_id = ?", seentweet.tweet_id)
		for oldurl in @oldurls
			oldurl.destroy
		end
		@oldtags = TweetTag.where("tweet_id = ?", seentweet.tweet_id)
		for oldtag in @oldtags
			oldtag.destroy
		end
		seentweet.destroy
	end
	
	@retweets = TweetRetweet.where("eloono_counted_flag = ? and created_at < ?", "yes", weekold)
	for retweet in @retweets
		retweet.destroy
	end
	
	@mentions = TweetMention.where("eloono_counted_flag = ? and created_at < ?", "yes", weekold)
	for mention in @mentions
		mention.destroy
	end
	
	erb "Done Here"
	
end

get '/send_connect_email' do

	@code = ""

	@recs = User.where("eloono_status = ?", "Recommended").order("big_eloono_score DESC").limit(1)
	
	for rec in @recs
		ftofratio = rec.followers_count.to_f/rec.friends_count.to_f
		ftofratio = ftofratio.round(2)
		tperday = rec.statuses_count.to_f/((((Time.now-rec.created_at)/60)/60)/24)
		tperday = tperday.round(2)
		recage = ((((Time.now-rec.created_at)/60)/60)/24)/365
		recage = recage.round(2)
		if recage < 1
			recagetext = "less than a year"
		else
			recagetext = recage.to_s+" years"
		end

		usertype = ""
		if rec.followers_count.to_f > 2500 and rec.friends_count.to_f > 2500 and ftofratio.to_f >= 2
			usertype = "a Marketer (indiscriminate net-worker)"
		elsif rec.friends_count.to_f > 4999 and ftofratio.to_f <= 0.5
			usertype = "a Pinger (they're just following anything that breathes)"
		elsif rec.followers_count.to_f > 4999 and ftofratio.to_f >= 5
			usertype = "a Celebrity (lots of followers, close set of friends)"
		elsif ftofratio.to_f >= 1
			usertype = "an Up and Comer (mentioned and re-tweeted but has a smaller network)"
		else
			usertype = "a 'Hmmmmmm' (not sure what to make of this person)"
		end

		recscore = rec.eloono_rec_score.to_i
		interactscore = rec.total_interactions.to_i
		appearscore = rec.num_appear.to_i

		@code = @code.to_s + %{<div class="rec_container" id="}+rec.user_id.to_s+%{"><a href="twitter://user?screen_name=}+rec.screen_name.to_s+%{" target="_blank"><img src="}+rec.profile_image_url.to_s+%{" height="33px" width="33px" /> }+rec.name.to_s+%{</a>}

		if rec.location != ""
			@code = @code.to_s+%{ | }+rec.location.to_s
		end
		if rec.url != ""
			@code = @code.to_s+%{ | <a href="}+rec.url.to_s+%{" target="_blank">Their URL</a>}
		end

		@code = @code.to_s+%{ | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/follow/}+rec.id.to_s+%{/direct" recid="}+rec.user_id.to_s+%{" target="_blank">Follow</a> | <a href="http://eloono.raleighgresham.com/rec_action/}+"none"+%{/ignore/}+rec.user_id.to_s+%{/na">Ignore</a>}

		@code = @code.to_s+%{<p style="text-align:center; padding-bottom:13px;"><em>}+rec.description.to_s+%{</em></p><p style="text-align:center; padding-bottom:13px; font-size:0.85em;">Interaction Score: }+interactscore.to_s+%{ | Categories Score: }+appearscore.to_s+%{ | Recommend Score: }+recscore.to_s+%{</p><p style="font-size:0.85em; text-align:left;">They are likely <b>}+usertype.to_s+%{</b> and have tweeted <b>}+rec.statuses_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse.to_s+%{</b> times at a rate of <b>}+tperday.to_s+%{</b> tweets per day. They have been on Twitter for <b>}+recagetext.to_s+%{</b>.</p></div>}
	end

	Pony.mail({
		:from => 'rg@raleighgresham.com',
		:to => 'raleigh.gresham@gmail.com',
		:subject => "Daily Eloono Recommendation",
		:html_body => @code,
		:via => :smtp,
		:via_options => {
			:address => 'pam.asoshared.com',
			:port => '26',
			:user_name => 'rg@raleighgresham.com',
			:password => 'r@ls0381',
			:authentication => :plain, 
			:domain => "localhost.localdomain" 
		}
	})

   erb "Done", :layout => false

end