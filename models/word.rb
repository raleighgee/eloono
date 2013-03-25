class Word < ActiveRecord::Base

	belongs_to :tweet
	belongs_to :itweet
	belongs_to :user

end
