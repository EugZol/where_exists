require 'test_helper'

ActiveRecord::Migration.create_table :belongs_to_simple_entities, :force => true do |t|
  t.string :name
  t.integer :my_id
end

ActiveRecord::Migration.create_table :belongs_to_simple_entity_children, :force => true do |t|
  t.integer :parent_id
  t.string :name
end

class BelongsToSimpleEntity < ActiveRecord::Base
  has_many :simple_entity_children, primary_key: :my_id, foreign_key: :parent_id, class_name: 'BelongsToSimpleEntityChild'
  has_many :unnamed_children, -> { where name: nil }, primary_key: :my_id, foreign_key: :parent_id, class_name: 'BelongsToSimpleEntityChild'
end

class BelongsToSimpleEntityChild < ActiveRecord::Base
  belongs_to :simple_entity, foreign_key: :parent_id, primary_key: :my_id, class_name: 'BelongsToSimpleEntity'
end

class BelongsToTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_nil_foreign_key
    _entity = BelongsToSimpleEntity.create!(my_id: 999)

    child = BelongsToSimpleEntityChild.create!(parent_id: 999)
    _orphaned_child = BelongsToSimpleEntityChild.create!(parent_id: nil)

    result = BelongsToSimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end

  def test_not_existing_foreign_object
    _entity = BelongsToSimpleEntity.create!(my_id: 999)

    child = BelongsToSimpleEntityChild.create!(parent_id: 999)
    _orphaned_child = BelongsToSimpleEntityChild.create!(parent_id: 500)

    result = BelongsToSimpleEntityChild.where_exists(:simple_entity)

    assert_equal 1, result.length
    assert_equal result.first.id, child.id
  end

  def test_with_parameters
    wrong_child = BelongsToSimpleEntityChild.create!(name: 'wrong')
    child = BelongsToSimpleEntityChild.create!(name: 'right')

    _blank_entity = BelongsToSimpleEntity.create!(my_id: 999)
    _wrong_entity = BelongsToSimpleEntity.create!(simple_entity_children: [wrong_child], my_id: 500)
    entity = BelongsToSimpleEntity.create!(name: 'this field is irrelevant', simple_entity_children: [child], my_id: 300)

    result = BelongsToSimpleEntity.where_exists(:simple_entity_children, name: 'right')

    assert_equal 1, result.length
    assert_equal result.first.id, entity.id
  end
end
