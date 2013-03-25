class Score < ActiveRecord::Base
  # attr_accessible :title, :body
  
  belongs_to :tweet
  belongs_to :itweet
  belongs_to :user
  
end
