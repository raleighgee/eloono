class Connection < ActiveRecord::Base

	belongs_to :user
	belongs_to :tweet
	belongs_to :itweet
	belongs_to :source

end
