require 'active_record'

module WhereExists
  def where_exists_or_not_exists(does_exist, association, where_parameters)
    association = self.reflect_on_association(association)
    association_model = association.class_name.constantize

    self_ids = connection.quote(self.table_name) + '.' + connection.quote(self.primary_key)
    association_ids = connection.quote(association_model.table_name) + '.' + connection.quote(association.foreign_key)

    not_string = unless does_exist
      "NOT "
    else
      ""
    end

    r = self.where("#{not_string}EXISTS(" +
      association_model.select(ActiveRecord::FinderMethods::ONE_AS_ONE).
        where("#{association_ids} = #{self_ids}").where(where_parameters).to_sql +
    ")")
    puts r.to_sql
    r
  end

  def where_exists(association, where_parameters = {})
    where_exists_or_not_exists(true, association, where_parameters)
  end

  def where_not_exists(association, where_parameters = {})
    where_exists_or_not_exists(false, association, where_parameters)
  end
end

class ActiveRecord::Base
  extend WhereExists
end