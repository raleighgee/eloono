class CreateConnections < ActiveRecord::Migration
	def change
		create_table :connections do |t|
			t.integer :source_id
			t.integer :tweet_id
			t.string :twitter_id, :default => "wait"
			t.integer :user_id
			t.string :user_name, :default => "wait"
			t.string :user_screen_name, :default => "wait"
			t.string :profile_image_url, :default => "wait"
			t.integer :num_appears, :default => 0
			t.text :user_description
			t.timestamps
		end
	end
end
