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
  s.description = "#where_exists extension of ActiveRecord"
  s.license     = "MIT"

  s.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.markdown"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.2.22"

  s.add_development_dependency "sqlite3"
end
