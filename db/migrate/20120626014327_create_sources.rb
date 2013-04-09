class CreateSources < ActiveRecord::Migration
	def change
		create_table :sources do |t|
			t.integer :user_id
			t.string :twitter_id
			t.float :score, :default => 1
			t.integer :statuses_count
			t.integer :favorites_count
			t.string :profile_image_url
			t.string :user_name, :default => "not seen"
			t.integer :listed_count
			t.string :following_flag
			t.text :user_description
			t.string :location
			t.integer :followers_count
			t.string :user_url
			t.string :user_screen_name
			t.integer :friends_count
			t.string :user_language
			t.string :user_time_zone
			t.datetime :twitter_created_at
			t.integer :number_links_followed, :default => 0
			t.float :tweets_per_hour, :default => 0
			t.integer :ignores, :default => 0
			t.float :net_interaction_score, :default => 0
			t.float :average_word_score, :default => 0
			t.integer :word_score_rank, :default => 1
			t.integer :interaction_score_rank, :default => 1
			t.string :tweets_at
			t.float :total_tweets_seen
			t.float :num_followers_rank
			t.float :tph_rank
			t.float :times_in_bottom, :default => 0
			t.float :times_in_top, :default => 0
			t.string :target_flag, :default => "no"
			t.timestamps
		end
	end
end
