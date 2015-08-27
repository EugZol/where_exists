require 'test_helper'

class SimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children
end

class SimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity
end

class HasManyTest < Minitest::Test
  def test_works_without_parameters
    child = SimpleEntityChild.create

    blank_entity = SimpleEntity.create
    filled_entity = SimpleEntity.create(simple_entity_children: [child])

    result = SimpleEntity.where_exists(:simple_entity_children)
    assert_equal 1, result.length

    assert_equal result.first.id, filled_entity.id
  end
end
