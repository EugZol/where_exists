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
    queries_sql = build_exists_string(association_name, *where_parameters)

    if does_exist
      not_string = ""
    else
      not_string = "NOT "
    end

    self.where("#{not_string}(#{queries_sql})")
  end

  def build_exists_string(association_name, *where_parameters)
    association = self.reflect_on_association(association_name)

    unless association
      raise ArgumentError.new("where_exists: association - #{association_name} - #{association_name.inspect} not found on #{self.name}")
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
    queries_sql = queries.map { |query| "EXISTS (" + query.to_sql + ")" }.join(" OR ")
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
        query = query.instance_exec(&association_scope)
      end
      if polymorphic
        other_type = connection.quote(associated_model.name)
        query = query.where("#{self_type} = #{other_type}")
      end
      queries.push query
    end

    queries
  end

  def where_exists_for_has_many_query(association, where_parameters, next_association = {})
    if association.through_reflection
      raise ArgumentError.new(association) unless association.source_reflection
      next_association = {
        association: association.source_reflection,
        params: where_parameters,
        next_association: next_association
      }
      association = association.through_reflection

      case association.macro
      when :has_many, :has_one
        return where_exists_for_has_many_query(association, {}, next_association)
      when :has_and_belongs_to_many
        return where_exists_for_habtm_query(association, {}, next_association)
      else
        inspection = nil
        begin
          inspection = association.macros.inspect
        rescue
          inspection = association.macro
        end
        raise ArgumentError.new("where_exists: not supported association – #{inspection}")
      end
    end

    association_scope = next_association[:scope] || association.scope

    associated_model = association.klass
    primary_key = association.options[:primary_key] || self.primary_key

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    associated_ids = quote_table_and_column_name(associated_model.table_name, association.foreign_key)

    result = associated_model.select("1").where("#{associated_ids} = #{self_ids}")

    if association.options[:as]
      other_types = quote_table_and_column_name(associated_model.table_name, association.type)
      self_class = connection.quote(self.name)
      result = result.where("#{other_types} = #{self_class}")
    end

    if next_association[:association]
      return loop_nested_association(result, next_association)
    end

    if where_parameters != []
      result = result.where(*where_parameters)
    end

    if association_scope
      result = result.instance_exec(&association_scope)
    end

    [result]
  end

  def where_exists_for_habtm_query(association, where_parameters, next_association = {})
    association_scope = association.scope

    associated_model = association.klass

    primary_key = association.options[:primary_key] || self.primary_key

    join_table = [self.table_name, associated_model.table_name].sort.join("_")

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    join_ids = quote_table_and_column_name(join_table, association.foreign_key)
    associated_join_ids = quote_table_and_column_name(join_table, "#{associated_model.name.downcase}_id")
    associated_ids = quote_table_and_column_name(associated_model.table_name, associated_model.primary_key)

    result =
      associated_model.
      select("1").
      joins(
        <<-SQL
          INNER JOIN #{connection.quote_table_name(join_table)}
          ON #{associated_ids} = #{associated_join_ids}
        SQL
      ).
      where("#{join_ids} = #{self_ids}")

    if next_association[:association]
      return loop_nested_association(result, next_association)
    end

    if where_parameters != []
      result = result.where(*where_parameters)
    end

    if association_scope
      result = result.instance_exec(&association_scope)
    end

    [result]
  end

  def loop_nested_association(query, next_association = {}, nested = false)
    str = query.klass.build_exists_string(
      next_association[:association].name,
      *[
        *next_association[:params]
      ],
    )

    if next_association[:next_association] && next_association[:next_association][:association]
      subq = str.match(/\([^\(\)]+\)/mi)[0]
      str.sub!(subq,
        "(#{subq} AND (#{loop_nested_association(
          next_association[:association],
          next_association[:next_association],
          true
        )}))"
      )
    end

    nested ? str : [query.where(str)]
  end

  def quote_table_and_column_name(table_name, column_name)
    connection.quote_table_name(table_name) + '.' + connection.quote_column_name(column_name)
  end
end

class ActiveRecord::Base
  extend WhereExists
end
