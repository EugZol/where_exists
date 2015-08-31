# Where Exists
**Rails way to harness the power of SQL EXISTS condition**<br>
[![Gem Version](https://badge.fury.io/rb/where_exists.svg)](http://badge.fury.io/rb/where_exists)

## Description

<img src="http://i.imgur.com/psLfPoW.gif" alt="Exists" align="right" width="100" height="200">

This gem does exactly two things:

* Selects each model object for which there is a certain associated object
* Selects each model object for which there aren't any certain associated objects

It uses SQL [EXISTS condition](http://www.techonthenet.com/sql/exists.php) to do it fast, and extends ActiveRecord with `where_exists` and `where_not_exists` methods to make its usage simple and straightforward.

## Quick start

Add gem to Gemfile:

    gem 'where_exists'

and run `bundle install` as usual.

And now you have `where_exists` and `where_not_exists` methods available for your ActiveRecord models and relations.

Syntax:

```ruby
Model.where_exists(association, additional_finder_parameters)
```

Supported Rails versions: >= 3.2.22.

## Example of usage

Given there is User model:

```ruby
class User < ActiveRecord::Base
  has_many :connections
  has_many :groups, through: :connections
end
```

And Group:

```ruby
class Group < ActiveRecord::Base
  has_many :connections
  has_many :users, through: :connections
end
```

And standard many-to-many Connection:

```ruby
class Connection
  belongs_to :user
  belongs_to :group
end
```

What I want to do is to:

* Select users who don't belong to given set of Groups (groups with ids `[4,5,6]`)
* Select users who belong to one set of Groups (`[1,2,3]`) and don't belong to another (`[4,5,6]`)
* Select users who don't belong to a Group

Also, I don't want to:

* Fetch a lot of data from database to manipulate it with Ruby code. I know that will be inefficient in terms of CPU and memory (Ruby is much slower than any commonly used DB engine, and typically I want to rely on DB engine to do the heavy lifting)
* I tried queries like `User.joins(:group).where(group_id: [1,2,3]).where.not(group_id: [4,5,6])` and they return wrong results (some users from the result set belong to groups 4,5,6 *as well as* 1,2,3)
* I don't want to do `join` merely for the sake of only checking for existence, because I know that that is a pretty complex (i.e. CPU/memory-intensive) operation for DB

<sub><sup>If you wonder how to do that without the gem (i.e. essentially by writing SQL EXISTS statement manually) see that [StackOverflow answer](http://stackoverflow.com/a/32016347/5029266) (disclosure: it's self-answered question of a contributor of this gem).</sup></sub>

And now you are able to do all these things (and more) as simple as:

> Select only users who don't belong to given set of Groups (groups with ids `[4,5,6]`)

```ruby
# It's really neat, isn't it?
User.where_exists(:groups, id: [4,5,6])
```

<sub><sup>Notice that the second argument is `where` parameters for Group model</sup></sub>

> Select only users who belong to one set of Groups (`[1,2,3]`) and don't belong to another (`[4,5,6]`)

```ruby
# Chain-able like you expect them to be.
#
# Additional finder parameters is anything that
# could be fed to 'where' method.
#
# Let's use 'name' instead of 'id' here, for example.

User.where_exists(:groups, name: ['first','second','third']).
  where_not_exists(:groups, name: ['fourth','fifth','sixth'])
```

<sub><sup>It is possible to add as much attributes to the criteria as it is necessary, just as with regular `where(...)`</sub></sup>

> Select only users who don't belong to a Group

```ruby
# And that's just its basic capabilities
User.where_not_exists(:groups)
```

<sub><sup>Adding parameters (the second argument) to `where_not_exists` method is feasible as well, if you have such requirements.</sup></sub>

## Additional capabilities

**Q**: Does it support both `has_many` and `belongs_to` association type?<br>
**A**: Yes.


**Q**: Does it support polymorphic associations?<br>
**A**: Yes, both ways.


**Q**: Does it support multi-level (recursive) `:through` associations?<br>
**A**: You bet. (Now you can forget complex EXISTS or JOIN statetements in a pretty wide variety of similar cases.)

## Contributing

If you find that this gem lacks certain possibilities that you would have found useful, don't hesitate to create a [feature request](https://github.com/EugZol/where_exists/issues).

Also,

* Report bugs
* Submit pull request with new features or bug fixes
* Enhance or clarify the documentation that you are reading

## License

This project uses MIT license. See [`MIT-LICENSE`](https://github.com/EugZol/where_exists/blob/master/MIT-LICENSE) file for full text.
