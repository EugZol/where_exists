require_relative 'test_helper'

ActiveRecord::Migration.create_table :houses, force: true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :windows, force: true do |t|
  t.string :name
  t.integer :house_id
end

ActiveRecord::Migration.create_table :doors, force: true do |t|
  t.string :name
  t.integer :house_id
end

class House < ActiveRecord::Base
  has_many :windows
  has_many :doors
end

class Window < ActiveRecord::Base
  belongs_to :house
  has_many :doors, through: :house
end

class Door < ActiveRecord::Base
  belongs_to :house
end

class HasManyThroughBelongsToTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_through_belongs_to
    house = House.create! name: 'relevant'
    irrelevant_house = House.create! name: 'irrelevant'

    window = Window.create!(house: house)
    irrelevant_window = Window.create!(house: irrelevant_house)

    door = Door.create!(name: 'relevant', house: house)
    irrelevant_door = Door.create!(name: 'irrelevant', house: irrelevant_house)

    result = House.where_exists(:doors, name: 'relevant')
    assert_equal 1, result.length
    assert_equal house.id, result.first.id

    result = House.where_not_exists(:doors, name: 'relevant')
    assert_equal 1, result.length
    assert_equal irrelevant_house.id, result.first.id

    result = House.where_not_exists(:doors, "name = ?", 'relevant')
    assert_equal 1, result.length
    assert_equal irrelevant_house.id, result.first.id

    result = Window.where_exists(:doors, name: 'relevant')
    assert_equal 1, result.length
    assert_equal window.id, result.first.id
  end
end
