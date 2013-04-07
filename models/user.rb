class User < ActiveRecord::Base
  attr_accessible :name, :provider, :uid
  
  has_many :tweets
  has_many :itweets
  has_many :words
  has_many :connections
  has_many :links
  has_many :sources
  
  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.name = auth["info"]["name"]
    end
  end
  
end