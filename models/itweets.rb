class Itweets < ActiveRecord::Base
  # attr_accessible :title, :body
  
  has_many :links
	belongs_to :source
	has_many :words
	belongs_to :user
	has_many :connections
  
end
