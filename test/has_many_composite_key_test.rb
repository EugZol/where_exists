require 'test_helper'

ActiveRecord::Migration.create_table :composite_key_entities, force: true do |t|
  t.integer :first_key
  t.integer :second_key
  t.string :name
end

ActiveRecord::Migration.create_table :composite_key_entity_children, force: true do |t|
  t.integer :first_key
  t.integer :second_key
  t.string :name
end

class CompositeKeyEntity < ActiveRecord::Base
  has_many :composite_key_entity_children,
    foreign_key: %i[first_key second_key],
    primary_key: %i[first_key second_key],
    dependent: false,
    inverse_of: false
end

class CompositeKeyEntityChild < ActiveRecord::Base
end

class HasManyCompositeKeyTest < Minitest::Test
  def setup
    CompositeKeyEntity.delete_all
    CompositeKeyEntityChild.delete_all
  end

  def test_where_exists_with_composite_keys
    entity = CompositeKeyEntity.create!(first_key: 1, second_key: 10, name: 'matched')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'child')

    _no_match = CompositeKeyEntity.create!(first_key: 2, second_key: 20, name: 'unmatched')

    result = CompositeKeyEntity.where_exists(:composite_key_entity_children)

    assert_equal 1, result.length
    assert_equal entity.id, result.first.id
  end

  def test_where_not_exists_with_composite_keys
    _entity = CompositeKeyEntity.create!(first_key: 1, second_key: 10, name: 'matched')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'child')

    no_match = CompositeKeyEntity.create!(first_key: 2, second_key: 20, name: 'unmatched')

    result = CompositeKeyEntity.where_not_exists(:composite_key_entity_children)

    assert_equal 1, result.length
    assert_equal no_match.id, result.first.id
  end

  def test_where_exists_with_composite_keys_and_conditions
    entity = CompositeKeyEntity.create!(first_key: 1, second_key: 10, name: 'matched')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'right')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'wrong')

    _other = CompositeKeyEntity.create!(first_key: 3, second_key: 30, name: 'other')
    CompositeKeyEntityChild.create!(first_key: 3, second_key: 30, name: 'wrong')

    result = CompositeKeyEntity.where_exists(:composite_key_entity_children, name: 'right')

    assert_equal 1, result.length
    assert_equal entity.id, result.first.id
  end

  def test_where_exists_with_composite_keys_partial_match_does_not_match
    # Only first_key matches, second_key differs — should NOT match
    CompositeKeyEntity.create!(first_key: 1, second_key: 10, name: 'partial')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 99, name: 'child')

    result = CompositeKeyEntity.where_exists(:composite_key_entity_children)

    assert_equal 0, result.length
  end

  def test_where_exists_with_composite_keys_and_block
    entity = CompositeKeyEntity.create!(first_key: 1, second_key: 10, name: 'matched')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'right')
    CompositeKeyEntityChild.create!(first_key: 1, second_key: 10, name: 'wrong')

    result = CompositeKeyEntity.where_exists(:composite_key_entity_children) { |scope|
      scope.where(name: 'right')
    }

    assert_equal 1, result.length
    assert_equal entity.id, result.first.id
  end
end
