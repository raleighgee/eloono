class AddRanksToSources < ActiveRecord::Migration
  def up
    add_column :sources, :times_in_top, :float, :default => 0
	add_column :sources, :times_in_bottom, :float, :default => 0
  end

  def down
    remove_column :sources, :times_in_top
	remove_column :sources, :times_in_bottom
  end
end