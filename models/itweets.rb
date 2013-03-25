class Itweets < ActiveRecord::Base
  # attr_accessible :title, :body
  
  has_many :links
	belongs_to :source
	has_many :words
	has_many :scores
	belongs_to :user
  
end
