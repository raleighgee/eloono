class CreateSources < ActiveRecord::Migration
	def change
		create_table :sources do |t|
			t.integer :user_id
			t.integer :connection_id
			t.string :tweets_from
			t.float :num_tweets, :default => 1
			t.timestamps
		end
	end
end
