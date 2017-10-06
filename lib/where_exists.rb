require 'active_record'

module WhereExists
  def where_exists(association_name, *where_parameters)
    where_exists_or_not_exists(true, association_name, where_parameters)
  end

  def where_not_exists(association_name, *where_parameters)
    where_exists_or_not_exists(false, association_name, where_parameters)
  end

  protected

  def where_exists_or_not_exists(does_exist, association_name, where_parameters)
    association = self.reflect_on_association(association_name)

    unless association
      raise ArgumentError.new("where_exists: association #{association_name.inspect} not found on #{self.name}")
    end

    case association.macro
    when :belongs_to
      queries = where_exists_for_belongs_to_query(association, where_parameters)
    when :has_many, :has_one
      queries = where_exists_for_has_many_query(association, where_parameters)
    when :has_and_belongs_to_many
      queries = where_exists_for_habtm_query(association, where_parameters)
    else
      inspection = nil
      begin
        inspection = association.macros.inspect
      rescue
        inspection = association.macro
      end
      raise ArgumentError.new("where_exists: not supported association – #{inspection}")
    end

    if does_exist
      not_string = ""
    else
      not_string = "NOT "
    end

    queries_sql = queries.map{|query| "EXISTS (" + query.to_sql + ")"}.join(" OR ")

    self.where("#{not_string}(#{queries_sql})")
  end

  def where_exists_for_belongs_to_query(association, where_parameters)
    polymorphic = association.options[:polymorphic].present?

    association_scope = association.scope

    if polymorphic
      associated_models = self.select("DISTINCT #{connection.quote_column_name(association.foreign_type)}").pluck(association.foreign_type).map(&:constantize)
    else
      associated_models = [association.klass]
    end

    queries = []

    self_ids = quote_table_and_column_name(self.table_name, association.foreign_key)
    self_type = quote_table_and_column_name(self.table_name, association.foreign_type)

    associated_models.each do |associated_model|
      primary_key = association.options[:primary_key] || associated_model.primary_key
      other_ids = quote_table_and_column_name(associated_model.table_name, primary_key)
      query = associated_model.select("1").where("#{self_ids} = #{other_ids}")
      if where_parameters != []
        query = query.where(*where_parameters)
      end
      if association_scope
        result = result.instance_exec(&association_scope)
      end
      if polymorphic
        other_type = connection.quote(associated_model.name)
        query = query.where("#{self_type} = #{other_type}")
      end
      queries.push query
    end

    queries
  end

  def where_exists_for_has_many_query(association, where_parameters)
    through = association.options[:through].present?

    association_scope = association.scope

    if through
      next_association = association.source_reflection
      association = association.through_reflection
    end

    associated_model = association.klass
    primary_key = association.options[:primary_key] || self.primary_key

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    associated_ids = quote_table_and_column_name(associated_model.table_name, association.foreign_key)

    result = associated_model.select("1").where("#{associated_ids} = #{self_ids}")

    if association_scope
      result = result.instance_exec(&association_scope)
    end

    if association.options[:as]
      other_types = quote_table_and_column_name(associated_model.table_name, association.type)
      self_class = connection.quote(self.name)
      result = result.where("#{other_types} = #{self_class}")
    end

    if through
      result = result.where_exists(next_association.name, *where_parameters)
    else
      if where_parameters != []
        result = result.where(*where_parameters)
      end
    end

    [result]
  end

  def where_exists_for_habtm_query(association, where_parameters)
    associated_model = association.klass

    primary_key = association.options[:primary_key] || self.primary_key

    join_table = [self.table_name, associated_model.table_name].sort.join("_")

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    join_ids = quote_table_and_column_name(join_table, association.foreign_key)
    associated_join_ids = quote_table_and_column_name(join_table, "#{associated_model.name.downcase}_id")
    associated_ids = quote_table_and_column_name(associated_model.table_name, associated_model.primary_key)

    result = associated_model.
    select("1").
    joins(
      <<-SQL
        INNER JOIN #{connection.quote_table_name(join_table)}
        ON #{associated_ids} = #{associated_join_ids}
      SQL
    ).
    where("#{join_ids} = #{self_ids}")

    result = result.where(where_parameters)

    [result]
  end

  def quote_table_and_column_name(table_name, column_name)
    connection.quote_table_name(table_name) + '.' + connection.quote_column_name(column_name)
  end
end

class ActiveRecord::Base
  extend WhereExists
end
