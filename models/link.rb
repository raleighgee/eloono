class Link < ActiveRecord::Base

	belongs_to :tweet
	belongs_to :itweet
	belongs_to :user
	belongs_to :source

end
