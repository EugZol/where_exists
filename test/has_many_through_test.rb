require_relative 'test_helper'

ActiveRecord::Migration.create_table :projects, force: true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :tasks, force: true do |t|
  t.string :name
  t.integer :project_id
end

ActiveRecord::Migration.create_table :line_items, force: true do |t|
  t.string :name
  t.integer :invoice_id
  t.integer :task_id
end

ActiveRecord::Migration.create_table :work_details, force: true do |t|
  t.string :name
  t.integer :line_item_id
end

ActiveRecord::Migration.create_table :invoices, force: true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :blobs, force: true  do |t|
end

ActiveRecord::Migration.create_table :attachments, force: true  do |t|
  t.string     :name,     null: false
  t.references :record,   null: false, polymorphic: true, index: false
  t.references :blob,     null: false

  t.datetime :created_at, null: false

  t.index [ :record_type, :record_id, :name, :blob_id ], name: "index_attachments_uniqueness", unique: true
end

class Attachment < ActiveRecord::Base
  belongs_to :record, polymorphic: true, touch: true
  belongs_to :blob
end

class Blob < ActiveRecord::Base
  has_many :attachments

  scope :unattached, -> { left_joins(:attachments).where(Attachment.table_name => { blob_id: nil }) }

  before_destroy(prepend: true) do
    raise ActiveRecord::InvalidForeignKey if attachments.exists?
  end
end

class Project < ActiveRecord::Base
  has_many :tasks
  has_many :invoices, :through => :tasks
  has_many :project_line_items, :through => :tasks, :source => :line_items
  has_many :work_details, :through => :project_line_items

  has_many :attachments, as: :record
  has_many :blobs, through: :attachments, source: :blob
  has_many :relevant_attachments, -> { where(name: "relevant") }, as: :record, class_name: "Attachment", inverse_of: :record, dependent: false
  has_many :relevant_blobs, through: :relevant_attachments, class_name: "Blob", source: :blob
  has_many :irrelevant_attachments, -> { where(name: "irrelevant") }, as: :record, class_name: "Attachment", inverse_of: :record, dependent: false
  has_many :irrelevant_blobs, through: :irrelevant_attachments, class_name: "Blob", source: :blob
end

class Task < ActiveRecord::Base
  belongs_to :project

  has_many :invoices, :through => :line_items
  has_many :line_items
  has_many :scoped_line_items, -> { where(name: 'relevant') }, class_name: 'LineItem'
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
    project = Project.create! name: 'relevant'
    irrelevant_project = Project.create! name: 'irrelevant'

    task = Task.create!(project: project)
    irrelevant_task = Task.create!(project: irrelevant_project)

    invoice = Invoice.create!(name: 'relevant')
    irrelevant_invoice = Invoice.create!(name: 'irrelevant')

    line_item = LineItem.create!(name: 'relevant', task: task, invoice: invoice)
    irrelevant_line_item = LineItem.create!(name: 'relevant', task: irrelevant_task, invoice: irrelevant_invoice)

    _work_detail = WorkDetail.create!(line_item: line_item, name: 'relevant')
    _irrelevant_work_detail = WorkDetail.create!(line_item: irrelevant_line_item, name: 'irrelevant')

    blob = Blob.create!()
    _relevant_attachment = Attachment.create!(name: 'relevant', blob: blob, record: project)
    _irrelevant_attachment = Attachment.create!(name: 'irrelevant', blob: blob, record: irrelevant_project)

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

    result = Task.where_exists(:scoped_line_items)

    assert_equal 2, result.length

    result = Project.where_exists(:relevant_blobs)

    assert_equal 1, result.length
    assert_equal project.id, result.first.id

    result = Project.where_not_exists(:relevant_blobs)

    assert_equal 1, result.length
    assert_equal irrelevant_project.id, result.first.id

    result = Project.where_exists(:blobs)

    assert_equal 2, result.length

    result = Project.where_not_exists(:blobs)

    assert_equal 0, result.length
  end

  def test_with_yield
    project = Project.create! name: 'example_project'
    task = Task.create!(project: project)
    line_item = LineItem.create!(name: 'example_line_item', task: task)
    result = Project.where_exists(:project_line_items) { |scope| scope.where(name: 'example_line_item') }

    assert_equal 1, result.length
  end
end
