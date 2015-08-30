require 'test_helper'

ActiveRecord::Migration.create_table :first_polymorphic_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :second_polymorphic_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :polymorphic_children, :force => true do |t|
  t.integer :polymorphic_entity_id
  t.string :polymorphic_entity_type
  t.string :name
end

class PolymorphicChild < ActiveRecord::Base
  belongs_to :polymorphic_entity, polymorphic: true
end

class FirstPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: PolymorphicChild
end

class SecondPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: PolymorphicChild
end

class BelongsToPolymorphicTest < Minitest::Unit::TestCase
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_exists_only_one_kind
    first_entity = FirstPolymorphicEntity.create!
    second_entity = SecondPolymorphicEntity.create!
    second_entity.update_column(:id, first_entity.id + 1)

    first_child = PolymorphicChild.create!(polymorphic_entity: first_entity)
    second_child = PolymorphicChild.create!(polymorphic_entity: second_entity)
    really_orphaned_child = PolymorphicChild.create!(polymorphic_entity_type: 'FirstPolymorphicEntity', polymorphic_entity_id: second_entity.id)
    another_really_orphaned_child = PolymorphicChild.create!(polymorphic_entity_type: 'SecondPolymorphicEntity', polymorphic_entity_id: first_entity.id)

    result = PolymorphicChild.where_exists(:polymorphic_entity)

    assert_equal 2, result.length
    assert_equal [first_child, second_child].map(&:id).sort, result.map(&:id).sort
  end

  def test_neither_exists
    first_entity = FirstPolymorphicEntity.create!
    second_entity = SecondPolymorphicEntity.create!
    second_entity.update_column(:id, first_entity.id + 1)

    first_child = PolymorphicChild.create!(polymorphic_entity: first_entity)
    orphaned_child = PolymorphicChild.create!(polymorphic_entity_id: second_entity.id, polymorphic_entity_type: 'FirstPolymorphicEntity')

    result = PolymorphicChild.where_not_exists(:polymorphic_entity)

    assert_equal 1, result.length
    assert_equal orphaned_child.id, result.first.id
  end
end