$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "where_exists/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "where_exists"
  s.version     = WhereExists::VERSION
  s.authors     = ["Eugene Zolotarev"]
  s.email       = ["eugzol@gmail.com"]
  s.homepage    = "http://github.com/eugzol/where_exists"
  s.summary     = "#where_exists extension of ActiveRecord"
  s.description = 'Rails way to harness the power of SQL "EXISTS" statement'
  s.license     = "MIT"

  s.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.markdown"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.2", "< 7.1"

  s.add_development_dependency "sqlite3", "~> 1.4"
  s.add_development_dependency "minitest", "~> 5.10"
  s.add_development_dependency "rake", "~> 12.3"
  s.add_development_dependency "rdoc", "~> 6.0"
end
