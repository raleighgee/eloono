class CreateScores < ActiveRecord::Migration
	def change
		create_table :scores do |t|
			t.string :measure
			t.float :score, :default => 0
			t.integer :user_id
			t.timestamps
		end
	end
end
