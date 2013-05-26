class CreateWords < ActiveRecord::Migration
  def change
    create_table :words do |t|
      t.string :word
      t.float :seen_count, :default => 0
      t.float :follows, :default => 0
      t.float :score, :default => 0
      t.integer :user_id
      t.string :thumb_status, :default => "neutral" # down, up, neutral
      t.string :sys_ignore_flag, :default => "no"
      t.timestamps
    end
  end
end
