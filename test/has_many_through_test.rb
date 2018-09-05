require_relative 'test_helper'

ActiveRecord::Migration.create_table :projects, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :tasks, :force => true do |t|
  t.string :name
  t.integer :project_id
end

ActiveRecord::Migration.create_table :line_items, :force => true do |t|
  t.string :name
  t.integer :invoice_id
  t.integer :task_id
end

ActiveRecord::Migration.create_table :work_details, :force => true do |t|
  t.string :name
  t.integer :line_item_id
end

ActiveRecord::Migration.create_table :invoices, :force => true do |t|
  t.string :name
end

class Project < ActiveRecord::Base
  has_many :tasks
  has_many :invoices, :through => :tasks
  has_many :project_line_items, :through => :tasks, :source => :line_items
  has_many :work_details, :through => :project_line_items
end

class Task < ActiveRecord::Base
  belongs_to :project

  has_many :invoices, :through => :line_items
  has_many :line_items
end

class LineItem < ActiveRecord::Base
  belongs_to :invoice
  belongs_to :task
  has_many :work_details
end

class WorkDetail < ActiveRecord::Base
  belongs_to :line_item
end

class Invoice < ActiveRecord::Base
  has_many :tasks, :through => :line_item
  has_many :line_items
end

# Invoices ->  LineItems <- Tasks <- Project

class HasManyThroughTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_one_level_through
    ActiveRecord::Base.descendants.each(&:delete_all)

    project = Project.create!
    irrelevant_project = Project.create!

    task = Task.create!(project: project)
    irrelevant_task = Task.create!(project: irrelevant_project)

    _line_item = LineItem.create!(name: 'relevant', task: task)
    _irrelevant_line_item = LineItem.create!(name: 'irrelevant', task: irrelevant_task)

    result = Project.where_exists(:project_line_items, name: 'relevant')

    assert_equal 1, result.length
    assert_equal project.id, result.first.id

    result = Project.where_not_exists(:project_line_items, name: 'relevant')
    assert_equal 1, result.length
    assert_equal irrelevant_project.id, result.first.id
  end

  def test_deep_through
    ActiveRecord::Base.descendants.each(&:delete_all)

    project = Project.create! name: 'relevant'
    irrelevant_project = Project.create! name: 'irrelevant'

    task = Task.create!(project: project)
    irrelevant_task = Task.create!(project: irrelevant_project)

    invoice = Invoice.create!(name: 'relevant')
    irrelevant_invoice = Invoice.create!(name: 'irrelevant')

    line_item = LineItem.create!(task: task, invoice: invoice)
    irrelevant_line_item = LineItem.create!(task: irrelevant_task, invoice: irrelevant_invoice)

    _work_detail = WorkDetail.create!(line_item: line_item, name: 'relevant')
    _irrelevant_work_detail = WorkDetail.create!(line_item: irrelevant_line_item, name: 'irrelevant')

    result = Project.where_exists(:invoices, name: 'relevant')

    assert_equal 1, result.length
    assert_equal project.id, result.first.id

    result = Project.where_not_exists(:invoices, name: 'relevant')

    assert_equal 1, result.length
    assert_equal irrelevant_project.id, result.first.id

    result = Project.where_not_exists(:invoices, "name = ?", 'relevant')

    assert_equal 1, result.length
    assert_equal irrelevant_project.id, result.first.id

    result = Project.where_exists(:work_details, name: 'relevant')

    assert_equal 1, result.length
    assert_equal project.id, result.first.id

    result = Project.where_not_exists(:work_details, name: 'relevant')

    assert_equal 1, result.length
    assert_equal irrelevant_project.id, result.first.id
  end
end
