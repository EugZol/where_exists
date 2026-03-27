require 'test_helper'

ActiveRecord::Migration.create_table :users, :force => true do |t|
  t.string :name

  t.integer :overseeing_user_id
end

ActiveRecord::Migration.create_table :invitations, :force => true do |t|
  t.integer :user_id
  t.integer :invited_user_id
end

ActiveRecord::Migration.create_table :posts, :force => true do |t|
  t.integer :author_id
  t.string :content
  t.boolean :archived, default: false, null: false
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'User'
  has_many :comments

  scope :archived, -> { where(archived: true) }
end

class Invitation < ActiveRecord::Base
  belongs_to :user
  belongs_to :invited_user, class_name: 'User'
end

class User < ActiveRecord::Base
  belongs_to :overseeing_user, class_name: 'User', foreign_key: 'overseeing_user_id'
  has_many :subordinates, class_name: 'User', foreign_key: 'overseeing_user_id'
  has_many :invitations
  has_many :invitations_as_invited_user, class_name: 'Invitation', foreign_key: 'invited_user_id'
  has_many :invited_users, through: :invitations, source: :invited_user
  has_many :posts, -> { where(archived: false) }, foreign_key: 'author_id'
end


class SelfReferentialTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_can_find_users_by_invited_users
    random_user = User.create!(name: 'Random User')

    author = User.create!(name: 'Author')
    user = User.create!(name: 'User', invited_users: [author])

    Post.create! author: author, content: 'hi'
    Post.create! author: author, content: 'hi again', archived: true

    query = User.where_exists(:invited_users)

    refute_includes query.to_a, random_user
    assert_includes query.to_a, user
    assert_equal [user], query.to_a

    inverse_query = User.where_not_exists(:invited_users)

    assert_includes inverse_query.to_a, random_user
    refute_includes inverse_query.to_a, user
    assert_equal [random_user, author], inverse_query.to_a
  end

  def test_can_find_users_with_invitations
    random_user = User.create!(name: 'Random User')

    author = User.create!(name: 'Author')
    user = User.create!(name: 'User', invited_users: [author])

    Post.create! author: author, content: 'hi'
    Post.create! author: author, content: 'hi again', archived: true

    query = User.where_exists(:invitations)

    refute_includes query.to_a, random_user
    assert_includes query.to_a, user
    assert_equal [user], query.to_a

    inverse_query = User.where_not_exists(:invitations)
    assert_includes inverse_query.to_a, random_user
    refute_includes inverse_query.to_a, user
    assert_equal [random_user, author], inverse_query.to_a
  end

  def test_can_find_users_who_invited_specific_user
    random_user = User.create!(name: 'Random User')

    other_inviter = User.create!(name: 'Other Inviter', invited_users: [random_user])

    author = User.create!(name: 'Author')
    user = User.create!(name: 'User', invited_users: [author])

    Post.create! author: author, content: 'hi'
    Post.create! author: author, content: 'hi again', archived: true
  
    query = User.where_exists(:invited_users) { it.where(id: author.id) }
    binding.irb

    refute_includes query.to_a, other_inviter
    assert_includes query.to_a, user
    assert_equal [user], query.to_a

    query = User.where_not_exists(:invited_users) { it.where(id: author.id) }

    assert_includes query.to_a, other_inviter
    refute_includes query.to_a, user
    assert_equal [random_user, other_inviter, author], query.to_a
  end

  def test_can_find_users_who_invited_user_with_name
    random_user = User.create!(name: 'Random User')

    other_inviter = User.create!(name: 'Other Inviter', invited_users: [random_user])

    author = User.create!(name: 'Author')
    user = User.create!(name: 'User', invited_users: [author])

    Post.create! author: author, content: 'hi'
    Post.create! author: author, content: 'hi again', archived: true
    query = User.where_exists(:invitations) { it.joins(:user).where(user: { name: author.name }) }

    refute_includes query.to_a, other_inviter
    assert_includes query.to_a, user
    assert_equal [user], query.to_a

    query = User.where_not_exists(:invitations) { it.joins(:user).where(user: { name: author.name }) }

    assert_includes query.to_a, other_inviter
    refute_includes query.to_a, user
    assert_equal [random_user, other_inviter, author], query.to_a
  end

  def test_can_find_users_who_invited_users_with_posts
    random_user = User.create!(name: 'Random User')

    author = User.create!(name: 'Author')
    user = User.create!(name: 'User', invited_users: [author])

    Post.create! author: author, content: 'hi'
    Post.create! author: author, content: 'hi again', archived: true

    query = User.where_exists(:invited_users) { it.where_exists(:posts) }

    refute_includes query.to_a, random_user
    refute_includes query.to_a, author
    assert_includes query.to_a, user
    assert_equal [user], query.to_a

    query = User.where_not_exists(:invited_users) { it.where_exists(:posts) }
    assert_includes query.to_a, random_user
    assert_includes query.to_a, author
    refute_includes query.to_a, user
    assert_equal [random_user, author], query.to_a
  end

  def test_can_find_users_who_invited_users_with_archived_posts
    author1 = User.create!(name: 'Random User')
    inviting_user1 = User.create!(name: 'Inviting User', invited_users: [author1])
    Post.create! author: author1, content: 'hi'

    author2 = User.create!(name: 'Author')
    inviting_user2 = User.create!(name: 'User', invited_users: [author2])

    Post.create! author: author2, content: 'hi again', archived: true
  
    query = User.where_exists(:invited_users) { it.where_exists(:posts) { it.unscope(where: :archived).archived } }

    refute_includes query.to_a, author1
    refute_includes query.to_a, author2
    refute_includes query.to_a, inviting_user1
    assert_includes query.to_a, inviting_user2
    assert_equal [inviting_user2], query.to_a
  end

  # Tests to check for issues with direct self referential associations
  def test_can_find_users_with_overseeing_user
    overseeing_user = User.create!(name: 'Overseeing User')
    subordinate = User.create!(name: 'Subordinate', overseeing_user: overseeing_user)
    random_user = User.create!(name: 'Random User')

    query = User.where_exists(:overseeing_user)

    refute_includes query.to_a, random_user
    refute_includes query.to_a, overseeing_user
    assert_includes query.to_a, subordinate
    assert_equal [subordinate], query.to_a
  end

  def test_can_find_users_with_subordinates
    overseeing_user = User.create!(name: 'Overseeing User')
    subordinate = User.create!(name: 'Subordinate', overseeing_user: overseeing_user)
    random_user = User.create!(name: 'Random User')

    query = User.where_exists(:subordinates)

    refute_includes query.to_a, random_user
    refute_includes query.to_a, subordinate
    assert_includes query.to_a, overseeing_user
    assert_equal [overseeing_user], query.to_a
  end
end
