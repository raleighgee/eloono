class Tweet < ActiveRecord::Base

	has_many :links
	belongs_to :source
	has_many :words
	has_many :scores
	belongs_to :user

end
