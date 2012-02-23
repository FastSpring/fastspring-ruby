class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :name

      t.timestamps
    end
    
    User.create( :name => "Test User")
  end

  def self.down
    drop_table :users
  end
end
