class AddIndexes < ActiveRecord::Migration
	def up
		add_index :tweets, :source_id
		add_index :tweets, :user_id
		add_index :sources, :user_id
		add_index :sources, :user_screen_name
		add_index :sources, :twitter_id
		add_index :scores, :user_id
		add_index :scores, :measure
		add_index :words, :user_id
		add_index :words, :word
		add_index :links, :user_id
		add_index :connections, :user_id
		add_index :connections, :user_screen_name
	end
	def down
	end
end
