class CreateLinks < ActiveRecord::Migration
  def change
    create_table :links do |t|
      t.integer :tweet_id
      t.string :expanded_url
      t.integer :source_id
      t.integer :user_id
      t.timestamps
    end
  end
end
