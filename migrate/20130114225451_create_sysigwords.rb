class CreateSysigwords < ActiveRecord::Migration
  def change
    create_table :sysigwords do |t|
      t.string :word
      t.timestamps
    end
  end
end
