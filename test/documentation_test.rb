require 'test_helper'

ActiveRecord::Migration.create_table :users, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :groups, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :connections, :force => true do |t|
  t.integer :user_id
  t.integer :group_id
  t.string :name
end

class User < ActiveRecord::Base
  has_many :connections
  has_many :groups, through: :connections
end

class Group < ActiveRecord::Base
  has_many :connections
  has_many :users, through: :connections
end

class Connection < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end

class DocumentationTest < Minitest::Unit::TestCase
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_readme
    group1 = Group.create!(name: 'first')
    group2 = Group.create!(name: 'second')
    group3 = Group.create!(name: 'third')

    group4 = Group.create!(name: 'fourth')
    group5 = Group.create!(name: 'fifth')
    group6 = Group.create!(name: 'sixth')

    user1 = User.create!
    Connection.create!(user: user1, group: group1)

    user2 = User.create!
    Connection.create!(user: user2, group: group2)
    Connection.create!(user: user2, group: group6)

    user3 = User.create!
    Connection.create!(user: user3, group: group5)

    user4 = User.create!

    result = User.where_exists(:groups, id: [1,2,3])
    assert_equal 2, result.length
    assert_equal [user1, user2].map(&:id).sort, result.map(&:id).sort

    result = User.where_exists(:groups, id: [1,2,3]).where_not_exists(:groups, name: %w(fourth fifth sixth))
    assert_equal 1, result.length
    assert_equal user1.id, result.first.id

    result = User.where_not_exists(:groups)
    assert_equal 1, result.length
    assert_equal user4.id, result.first.id
  end
end