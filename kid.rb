class Kid < ActiveRecord::Base
  # attr_accessible :title, :body

	belongs_to :source
	belongs_to :user
  
end
