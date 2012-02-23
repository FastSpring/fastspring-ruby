class User < ActiveRecord::Base
  has_one :subscription, :dependent => :destroy
  attr_accessible :name
end
