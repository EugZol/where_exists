require 'test_helper'

ActiveRecord::Migration.create_table :simple_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :simple_entity_children, :force => true do |t|
  t.integer :simple_entity_id
  t.string :name
end

class SimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children
end

class SimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity
end

class BelongsToTest < Minitest::Unit::TestCase
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_nil_foreign_key
    entity = SimpleEntity.create!

    child = SimpleEntityChild.create!(simple_entity_id: entity.id)
    orphaned_child = SimpleEntityChild.create!(simple_entity_id: nil)

    result = SimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end

  def test_not_existing_foreign_object
    entity = SimpleEntity.create!

    child = SimpleEntityChild.create!(simple_entity_id: entity.id)
    orphaned_child = SimpleEntityChild.create!(simple_entity_id: entity.id + 1)

    result = SimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end
end