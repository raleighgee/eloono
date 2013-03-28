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
			t.integer :num_score_rounds, :default => 0
			t.integer :level, :default => 0
			t.string :language, :default => "en"
			t.integer :calls_left, :default => 350
			t.integer :number_eloonos_sent, :default => 0
			t.integer :num_tweets_pulled, :default => 0
			t.string :active_scoring, :default => "no"
			t.string :pay_key, :default => "0"
			t.string :sorting_by, :default => "age"
			t.float :amount_owed, :default => 0
			t.string :payment_status, :default => "paid"
			t.datetime :last_interaction, :default => Time.now
			t.float :current_score_threshold, :default => 0
			t.timestamps
		end
	end
end
