require 'test_helper'

ActiveRecord::Migration.create_table :posts, :force => true do |t|
  t.boolean :archived, default: false, null: false
end

ActiveRecord::Migration.create_table :comments, :force => true do |t|
  t.integer :post_id
  t.integer :commentator_id
end

ActiveRecord::Migration.create_table :commentators, :force => true do |t|
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :commentator
end

class Commentator < ActiveRecord::Base
  has_many :comments
  has_many :posts, -> { where(archived: false) }, through: :comments
end

class HasManyThroughConditionsTest < Minitest::Test
  def test_where_exists
    post = Post.create!
    archived_post = Post.create! archived: true

    commentator = Commentator.create! posts: [post]
    commentator2 = Commentator.create! posts: [archived_post]
    commentator3 = Commentator.create!

    assert_equal [commentator], Commentator.where_exists(:posts).to_a # fail: also includes commentator2
    assert_equal [commentator2, commentator3], Commentator.where_not_exists(:posts).to_a # fail: does not include commentator2
  end
end
