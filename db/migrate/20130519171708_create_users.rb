class CreateUsers < ActiveRecord::Migration
	def change
		create_table :users do |t|
			t.string :provider
			t.string :name
			t.string :handle
			t.string :profile_image_url
			t.string :secret, :default => "0"
			t.string :token, :default => "0"
			t.integer :uid, :limit => 8
			t.string :language, :default => "en"
			t.integer :num_tweets_shown, :default => 0
			t.integer :num_words_scored, :default => 0
			t.datetime :last_interaction, :default => Time.now
			t.float :avg_word_score, :default => 0
			t.float :min_word_score, :default => 0
			t.float :max_word_score, :default => 0
			t.float :firstq_word_score, :default => 0
			t.float :thirdq_word_score, :default => 0
			t.integer :lastest_tweet_id, :limit => 8,:default => 0
			t.timestamps
		end
	end
end
