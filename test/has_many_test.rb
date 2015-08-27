require 'test_helper'

class SimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children
end

class SimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity
end

class HasManyTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_without_parameters
    child = SimpleEntityChild.create

    blank_entity = SimpleEntity.create
    filled_entity = SimpleEntity.create(simple_entity_children: [child])

    result = SimpleEntity.where_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, filled_entity.id
  end

  def test_with_parameters
    wrong_child = SimpleEntityChild.create(name: 'wrong')
    child = SimpleEntityChild.create(name: 'right')

    blank_entity = SimpleEntity.create
    wrong_entity = SimpleEntity.create(simple_entity_children: [wrong_child])
    entity = SimpleEntity.create(name: 'this field is irrelevant', simple_entity_children: [child])

    result = SimpleEntity.where_exists(:simple_entity_children, name: 'right')

    assert_equal 1, result.length
    assert_equal result.first.id, entity.id
  end

  def test_with_scope
    child = SimpleEntityChild.create
    entity = SimpleEntity.create(simple_entity_children: [child])

    result = SimpleEntity.unscoped.where_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, entity.id
  end

  def test_not_exists
    child = SimpleEntityChild.create

    blank_entity = SimpleEntity.create
    filled_entity = SimpleEntity.create(simple_entity_children: [child])

    result = SimpleEntity.where_not_exists(:simple_entity_children)

    assert_equal 1, result.length
    assert_equal result.first.id, blank_entity.id
  end
end
