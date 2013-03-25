class Source < ActiveRecord::Base

	has_many :tweets
	has_many :itweets
	has_many :links
	has_many :kids
	belongs_to :user

end
