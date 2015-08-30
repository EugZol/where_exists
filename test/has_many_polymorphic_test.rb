require 'test_helper'

ActiveRecord::Migration.create_table :relevant_polymorphic_entities, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :irrelevant_polymorphic_entities, :force => true do |t|
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

class RelevantPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: PolymorphicChild
end

class IrrelevantPolymorphicEntity < ActiveRecord::Base
  has_many :children, as: :polymorphic_entity, class_name: PolymorphicChild
end

class HasManyPolymorphicTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_polymorphic
    child = PolymorphicChild.create!

    irrelevant_entity = IrrelevantPolymorphicEntity.create!(children: [child])
    relevant_entity = RelevantPolymorphicEntity.create!(id: irrelevant_entity.id)

    result = RelevantPolymorphicEntity.where_exists(:children)

    assert_equal 0, result.length
  end
end