class CreateWords < ActiveRecord::Migration
  def change
    create_table :words do |t|
      t.string :word
      t.integer :seen_count, :default => 0
      t.integer :follows, :default => 0
      t.integer :score, :default => 0
	  t.float :comp_average, :default => 0
      t.integer :user_id
      t.string :sys_ignore_flag, :default => "no"
      t.timestamps
    end
  end
end
