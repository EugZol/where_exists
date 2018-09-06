require 'test_helper'

ActiveRecord::Migration.create_table :simple_entities, :force => true do |t|
  t.string :name
  t.integer :my_id
end

ActiveRecord::Migration.create_table :simple_entity_children, :force => true do |t|
  t.integer :parent_id
  t.datetime :my_date
  t.string :name
end

class SimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children, primary_key: :my_id, foreign_key: :parent_id
  has_many :unnamed_children, -> { where name: nil }, primary_key: :my_id, foreign_key: :parent_id, class_name: 'SimpleEntityChild'
end

class SimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity, foreign_key: :parent_id
end

class HasManyTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_without_parameters
    child = SimpleEntityChild.create!

    _blank_entity = SimpleEntity.create!(my_id: 999)
    filled_entity = SimpleEntity.create!(simple_entity_children: [child], my_id: 500)

    result = SimpleEntity.where_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, filled_entity.id
  end

  def test_with_parameters
    wrong_child = SimpleEntityChild.create!(name: 'wrong')
    child = SimpleEntityChild.create!(name: 'right')

    _blank_entity = SimpleEntity.create!(my_id: 999)
    _wrong_entity = SimpleEntity.create!(simple_entity_children: [wrong_child], my_id: 500)
    entity = SimpleEntity.create!(name: 'this field is irrelevant', simple_entity_children: [child], my_id: 300)

    result = SimpleEntity.where_exists(:simple_entity_children, name: 'right')

    assert_equal 1, result.length
    assert_equal result.first.id, entity.id
  end

  def test_with_scope
    child = SimpleEntityChild.create!
    entity = SimpleEntity.create!(simple_entity_children: [child], my_id: 999)

    result = SimpleEntity.unscoped.where_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, entity.id
  end

  def test_with_condition
    child_1 = SimpleEntityChild.create! name: nil
    child_2 = SimpleEntityChild.create! name: 'Luke'

    entity_1 = SimpleEntity.create!(simple_entity_children: [child_1], my_id: 999)
    entity_2 = SimpleEntity.create!(simple_entity_children: [child_2], my_id: 500)

    result = SimpleEntity.unscoped.where_exists(:unnamed_children)
    assert_equal 1, result.length
    assert_equal result.first.id, entity_1.id

    result = SimpleEntity.unscoped.where_not_exists(:unnamed_children)
    assert_equal 1, result.length
    assert_equal result.first.id, entity_2.id
  end

  def test_not_exists
    child = SimpleEntityChild.create!

    blank_entity = SimpleEntity.create!(my_id: 999)
    _filled_entity = SimpleEntity.create!(simple_entity_children: [child], my_id: 500)

    result = SimpleEntity.where_not_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, blank_entity.id
  end

  def test_dynamic_scopes
    child_past = SimpleEntityChild.create! my_date: Time.now - 1.minute
    child_future = SimpleEntityChild.create! my_date: Time.now + 1.minute

    _blank_entity = SimpleEntity.create!(simple_entity_children: [child_future], my_id: 999)
    filled_entity = SimpleEntity.create!(simple_entity_children: [child_past], my_id: 500)

    result = SimpleEntity.where_exists(:simple_entity_children) {|scope|
      scope.where('my_date < ?', Time.now)
    }

    assert_equal 1, result.length
    assert_equal result.first.id, filled_entity.id
  end
end
