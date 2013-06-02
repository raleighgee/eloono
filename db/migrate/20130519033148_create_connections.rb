class CreateConnections < ActiveRecord::Migration
	def change
		create_table :connections do |t|
			t.integer :user_id
			t.string :connection_type, :default => "source" # mentioned, recommended, ignore
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
			t.float :statuses_count
			t.float :total_tweets_seen
			t.float :followers_count
			t.float :friends_count
			t.float :tweets_per_hour
			t.float :average_word_score, :default => 0
			t.float :average_stream_word_score, :default => 0
			t.float :appearances, :default => 0
			t.float :overall_index, :default => 0
			t.float :tone_score, :default => 0
			t.float :ttwo_score, :default => 0
			t.float :tthree_score, :default => 0
			t.integer :tone_tweet_id, :default => 0, :limit => 8
			t.integer :ttwo_tweet_id, :default => 0, :limit => 8
			t.integer :tthree_tweet_id, :default => 0, :limit => 8
			t.timestamps
		end
	end
end
