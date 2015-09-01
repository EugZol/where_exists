require 'test_helper'

ActiveRecord::Migration.create_table :simple_entities, :force => true do |t|
  t.string :name
  t.integer :my_id
end

ActiveRecord::Migration.create_table :simple_entity_children, :force => true do |t|
  t.integer :parent_id
  t.string :name
end

class SimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children, primary_key: :my_id, foreign_key: :parent_id
end

class SimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity, foreign_key: :parent_id, primary_key: :my_id
end

class BelongsToTest < Minitest::Unit::TestCase
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_nil_foreign_key
    entity = SimpleEntity.create!(my_id: 999)

    child = SimpleEntityChild.create!(parent_id: 999)
    orphaned_child = SimpleEntityChild.create!(parent_id: nil)

    result = SimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end

  def test_not_existing_foreign_object
    entity = SimpleEntity.create!(my_id: 999)

    child = SimpleEntityChild.create!(parent_id: 999)
    orphaned_child = SimpleEntityChild.create!(parent_id: 500)

    result = SimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end
end