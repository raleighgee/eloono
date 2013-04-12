class CreateConnections < ActiveRecord::Migration
	def change
		create_table :connections do |t|
			t.integer :source_id
			t.integer :tweet_id
			t.integer :twitter_id, :limit => 8
			t.integer :user_id
			t.string :user_name, :default => "wait"
			t.string :user_screen_name, :default => "wait"
			t.string :profile_image_url, :default => "wait"
			t.integer :num_appears, :default => 1
			t.float :avg_assoc_tweet_score, :default => 0
			t.text :user_description, :default => "wait"
			t.string :profile_image_url, :default => "wait"
			t.timestamps
		end
	end
end
