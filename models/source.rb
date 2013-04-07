class Source < ActiveRecord::Base

	has_many :tweets
	has_many :itweets
	has_many :connections
	has_many :links
	belongs_to :user

end
