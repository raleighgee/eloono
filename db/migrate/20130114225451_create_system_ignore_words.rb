class CreateSystemIgnoreWords < ActiveRecord::Migration
  def change
    create_table :system_ignore_words do |t|
      t.string :word
      t.timestamps
    end
  end
end
