class Tweet < ActiveRecord::Base

	has_many :links
	belongs_to :source
	has_many :words
	belongs_to :user
	has_many :connections

end
