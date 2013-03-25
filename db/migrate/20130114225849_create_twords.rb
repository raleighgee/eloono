class CreateTwords < ActiveRecord::Migration
  def change
    create_table :twords do |t|
      t.string :word
      t.integer :rank
      t.integer :score, :default => 0
      t.integer :user_id
      t.timestamps
    end
  end
end
