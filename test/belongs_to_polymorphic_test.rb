require 'test_helper'

ActiveRecord::Migration.create_table :first_polymorphic_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :second_polymorphic_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :belongs_to_polymorphic_children, :force => true do |t|
  t.integer :polymorphic_entity_id
  t.string :polymorphic_entity_type
  t.string :name
end

class BelongsToPolymorphicChild < ActiveRecord::Base
  belongs_to :polymorphic_entity, polymorphic: true
end

class FirstPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: 'BelongsToPolymorphicChild'
end

class SecondPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: 'BelongsToPolymorphicChild'
end

class BelongsToPolymorphicTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_exists_only_one_kind
    first_entity = FirstPolymorphicEntity.create!
    second_entity = SecondPolymorphicEntity.create!
    second_entity.update_column(:id, first_entity.id + 1)

    first_child = BelongsToPolymorphicChild.create!(polymorphic_entity: first_entity)
    second_child = BelongsToPolymorphicChild.create!(polymorphic_entity: second_entity)
    _really_orphaned_child = BelongsToPolymorphicChild.create!(polymorphic_entity_type: 'FirstPolymorphicEntity', polymorphic_entity_id: second_entity.id)
    _another_really_orphaned_child = BelongsToPolymorphicChild.create!(polymorphic_entity_type: 'SecondPolymorphicEntity', polymorphic_entity_id: first_entity.id)

    result = BelongsToPolymorphicChild.where_exists(:polymorphic_entity)

    assert_equal 2, result.length
    assert_equal [first_child, second_child].map(&:id).sort, result.map(&:id).sort
  end

  def test_neither_exists
    first_entity = FirstPolymorphicEntity.create!
    second_entity = SecondPolymorphicEntity.create!
    second_entity.update_column(:id, first_entity.id + 1)

    _first_child = BelongsToPolymorphicChild.create!(polymorphic_entity: first_entity)
    orphaned_child = BelongsToPolymorphicChild.create!(polymorphic_entity_id: second_entity.id, polymorphic_entity_type: 'FirstPolymorphicEntity')

    result = BelongsToPolymorphicChild.where_not_exists(:polymorphic_entity)

    assert_equal 1, result.length
    assert_equal orphaned_child.id, result.first.id
  end

  def test_no_entities_or_empty_child_relation
    result = BelongsToPolymorphicChild.where_not_exists(:polymorphic_entity)
    assert_equal 0, result.length

    _first_child = BelongsToPolymorphicChild.create!
    result = BelongsToPolymorphicChild.where_not_exists(:polymorphic_entity)
    assert_equal 1, result.length

    result = BelongsToPolymorphicChild.where_exists(:polymorphic_entity)
    assert_equal 0, result.length
  end

  def test_table_name_based_lookup
    first_entity = FirstPolymorphicEntity.create!
    second_entity = SecondPolymorphicEntity.create! id: first_entity.id + 1

    first_child = BelongsToPolymorphicChild.create!(polymorphic_entity_id: first_entity.id, polymorphic_entity_type: first_entity.class.table_name)
    second_child = BelongsToPolymorphicChild.create!(polymorphic_entity_id: second_entity.id, polymorphic_entity_type: second_entity.class.table_name)
    orphaned_child = BelongsToPolymorphicChild.create!(polymorphic_entity_id: second_entity.id, polymorphic_entity_type: first_entity.class.table_name)

    result = BelongsToPolymorphicChild.where_exists(:polymorphic_entity)
    assert_equal 2, result.length
    assert_equal [first_child, second_child].map(&:id).sort, result.map(&:id).sort

    result = BelongsToPolymorphicChild.where_not_exists(:polymorphic_entity)
    assert_equal 1, result.length
    assert_equal [orphaned_child].map(&:id).sort, result.map(&:id).sort
  end
end
