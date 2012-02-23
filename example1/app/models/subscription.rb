class Subscription < ActiveRecord::Base
  belongs_to :user
  attr_accessible :reference
end
