class CreateItweets < ActiveRecord::Migration
	def change
		create_table :itweets do |t|
			t.integer :old_id
			t.datetime :old_created_at
			t.integer :source_id
			t.string :twitter_id
			t.integer :user_id
			t.float :score, :default => 1
			t.string :tweet_type
			t.integer :url_count, :default => 0
			t.string :followed_flag, :default => "no"
			t.string :last_action, :default => "new"
			t.datetime :twitter_created_at
			t.integer :retweet_count, :default => 0
			t.string :tweet_source
			t.string :tweet_content
			t.text :clean_tweet_content
			t.string :truncated_flag
			t.string :reply_id, :default => "0"
			t.string :convo_flag, :default => "no"
			t.string :convo_initiator, :default => "None"
			t.float :word_quality_score, :default => 0
			t.float :source_score_score, :default => 0
			t.timestamps
		end
	end
end
