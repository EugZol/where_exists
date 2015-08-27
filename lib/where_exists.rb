require 'active_record'

module WhereExists
  def where_exists(association)
    association = self.reflect_on_association(association)
    association_model = association.class_name.constantize

    self_ids = connection.quote(self.table_name) + '.' + connection.quote(self.primary_key)
    association_ids = connection.quote(association_model.table_name) + '.' + connection.quote(association.foreign_key)

    r = self.where("EXISTS (" +
      association_model.select(ActiveRecord::FinderMethods::ONE_AS_ONE).
        where("#{association_ids} = #{self_ids}").to_sql +
    ")")
    puts r.to_sql
    r
  end
end

class ActiveRecord::Base
  extend WhereExists
end