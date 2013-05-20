class CreateConnections < ActiveRecord::Migration
	def change
		create_table :connections do |t|
			t.integer :user_id
			t.integer :twitter_id, :limit => 8
			t.string :profile_image_url, :default => "wait"
			t.string :user_name, :default => "not seen"
			t.string :following_flag, :default => "wait"
			t.text :user_description, :default => "wait"
			t.string :user_url, :default => "wait"
			t.string :user_screen_name, :default => "wait"
			t.string :user_language, :default => "wait"
			t.string :location, :default => "wait"
			t.datetime :twitter_created_at
			t.float :average_word_score, :default => 0
			t.string :earliest_tweets_at
			t.string :latest_tweets_at
			t.string :avg_tweets_at
			t.float :total_tweets_seen
			t.float :times_in_top, :default => 0
			t.string :connection_type, :default => "mentioned" # mentioned, recommended, following, tagret, ignore
			t.float :statuses_count
			t.float :followers_count
			t.float :friends_count
			t.float :tweets_per_hour
			t.timestamps
		end
	end
end
