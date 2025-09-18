require 'minitest/autorun'
require 'minitest/pride'
require 'bundler/setup'
Bundler.require(:default)
require 'active_record'
require File.dirname(__FILE__) + '/../lib/where_exists'

# Rails < 7.1
if ActiveRecord::Base.respond_to?(:default_timezone=)
  ActiveRecord::Base.default_timezone = :utc
else
  ActiveRecord.default_timezone = :utc
end

ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(STDOUT)
