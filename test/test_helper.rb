require 'minitest/autorun'
require 'minitest/pride'
require 'bundler/setup'
Bundler.require(:default)
require 'active_record'
require File.dirname(__FILE__) + '/../lib/where_exists'

if ActiveRecord.version < Gem::Version.new("7.1")
  ActiveRecord::Base.default_timezone = :utc
else
  ActiveRecord.default_timezone = :utc
end

ActiveRecord::Base.time_zone_aware_attributes = true

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => File.dirname(__FILE__) + "/db/test.db"
)
