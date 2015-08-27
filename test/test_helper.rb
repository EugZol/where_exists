require 'minitest/autorun'
require 'minitest/pride'
require 'bundler/setup'
Bundler.require(:default)
require 'active_record'
require File.dirname(__FILE__) + '/../lib/where_exists'

ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => File.dirname(__FILE__) + "/db/test.db"
)

ActiveRecord::Migration.create_table :simple_entities, :force => true do |t|
end

ActiveRecord::Migration.create_table :simple_entity_children, :force => true do |t|
  t.integer :simple_entity_id
end