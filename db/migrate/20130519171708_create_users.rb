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
			t.float :avg_word_score, :default => 0
			t.float :min_word_score, :default => 0
			t.float :max_word_score, :default => 0
			t.float :firstq_word_score, :default => 0
			t.float :thirdq_word_score, :default => 0
			t.float :avg_tweet_score, :default => 0
			t.float :min_tweet_score, :default => 0
			t.float :max_tweet_score, :default => 0
			t.float :firstq_tweet_score, :default => 0
			t.float :thirdq_tweet_score, :default => 0
			t.integer :latest_tweet_id, :limit => 8, :default => 0
			t.text :last_tweets
			t.string :email
			t.datetime :last_wordscore, :default => Time.now
			t.datetime :last_connectionsscore, :default => Time.now
			t.datetime :last_tweetemail, :default => Time.now
			t.datetime :last_wordemail, :default => Time.now
			t.datetime :last_connectionsemail, :default => Time.now
			t.string :active_scoring_flag, :default => "no"
			t.timestamps
		end
	end
end
