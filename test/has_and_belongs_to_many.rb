require 'test_helper'

ActiveRecord::Migration.create_table :tasks, :force => true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :invoices_tasks, :force => true do |t|
  t.integer :invoice_id
  t.integer :task_id
end

ActiveRecord::Migration.create_table :invoices, :force => true do |t|
  t.string :name
end

class Task < ActiveRecord::Base
  has_and_belongs_to_many :connected_invoices, class_name: 'Invoice'
end

class Invoice < ActiveRecord::Base
  has_and_belongs_to_many :tasks
end

# Invoices ->  LineItems <- Tasks <- Project

class HasAndBelongsToManyTest < Minitest::Test
  def setup
    ActiveRecord::Base.descendants.each(&:delete_all)
  end

  def test_with_standard_naming
    task = Task.create!(name: 'task')
    irrelevant_task = Task.create!(name: 'task_2')
    invoice = Invoice.create!(name: 'invoice')
    invoice_no_join = Invoice.create!(name: 'invoice_2')

    invoice.tasks << task


    result = Invoice.where_exists(:tasks, name: 'task')

    assert_equal 1, result.length
    assert_equal invoice.id, result.first.id

    result = Invoice.where_exists(:tasks, name: 'task_2')

    assert_equal 0, result.length

    result = Invoice.where_not_exists(:tasks)
    assert_equal 1, result.length
    assert_equal invoice_no_join.id, result.first.id
  end

  def test_with_custom_naming
    task = Task.create!(name: 'task')
    task_no_join = Task.create!(name: 'invoice')
    invoice = Invoice.create!(name: 'invoice')
    irrelevant_invoice = Invoice.create!(name: 'invoice_2')

    task.connected_invoices << invoice


    result = Task.where_exists(:connected_invoices, name: 'invoice')

    assert_equal 1, result.length
    assert_equal task.id, result.first.id

    result = Task.where_exists(:connected_invoices, name: 'invoice_2')

    assert_equal 0, result.length

    result = Task.where_not_exists(:connected_invoices)
    assert_equal 1, result.length
    assert_equal task_no_join.id, result.first.id

    result = Task.where_not_exists(:connected_invoices, name: 'invoice_2')
    assert_equal 2, result.length
  end
end
