require 'active_record'

module WhereExists
  def where_exists(association_name, *where_parameters, &block)
    where_exists_or_not_exists(true, association_name, where_parameters, &block)
  end

  def where_not_exists(association_name, *where_parameters, &block)
    where_exists_or_not_exists(false, association_name, where_parameters, &block)
  end

  protected

  def where_exists_or_not_exists(does_exist, association_name, where_parameters, &block)
    queries_sql = build_exists_string(association_name, *where_parameters, &block)

    if does_exist
      not_string = ""
    else
      not_string = "NOT "
    end

    if queries_sql.empty?
      does_exist ? self.none : self.all
    else
      self.where("#{not_string}(#{queries_sql})")
    end
  end

  def build_exists_string(association_name, *where_parameters, &block)
    association = self.reflect_on_association(association_name)

    unless association
      raise ArgumentError.new("where_exists: association - #{association_name} - #{association_name.inspect} not found on #{self.name}")
    end

    case association.macro
    when :belongs_to
      queries = where_exists_for_belongs_to_query(association, where_parameters, &block)
    when :has_many, :has_one
      queries = where_exists_for_has_many_query(association, where_parameters, &block)
    when :has_and_belongs_to_many
      queries = where_exists_for_habtm_query(association, where_parameters, &block)
    else
      inspection = nil
      begin
        inspection = association.macros.inspect
      rescue
        inspection = association.macro
      end
      raise ArgumentError.new("where_exists: not supported association - #{inspection}")
    end

    queries_sql =
      queries.map do |query|
        "EXISTS (" + query.to_sql + ")"
      end
    queries_sql.join(" OR ")
  end

  def where_exists_for_belongs_to_query(association, where_parameters, &block)
    polymorphic = association.options[:polymorphic].present?

    association_scope = association.scope

    if polymorphic
      associated_models = self.select("DISTINCT #{connection.quote_column_name(association.foreign_type)}").
        where("#{connection.quote_column_name(association.foreign_type)} IS NOT NULL").pluck(association.foreign_type).
        uniq.map(&:classify).map(&:constantize)
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
        other_types = [associated_model.name, associated_model.table_name]
        other_types << associated_model.polymorphic_name if associated_model.respond_to?(:polymorphic_name)

        query = query.where("#{self_type} IN (?)", other_types.uniq)
      end
      query = yield query if block_given?
      queries.push query
    end

    queries
  end

  def where_exists_for_has_many_query(association, where_parameters, next_association = {}, &block)
    if association.through_reflection
      raise ArgumentError.new(association) unless association.source_reflection
      next_association = {
        association: association.source_reflection,
        params: where_parameters,
        next_association: next_association,
        scope: association.scope
      }
      association = association.through_reflection

      case association.macro
      when :has_many, :has_one, :belongs_to
        return where_exists_for_has_many_query(association, {}, next_association, &block)
      when :has_and_belongs_to_many
        return where_exists_for_habtm_query(association, {}, next_association, &block)
      else
        inspection = nil
        begin
          inspection = association.macros.inspect
        rescue
          inspection = association.macro
        end
        raise ArgumentError.new("where_exists: not supported association - #{inspection}")
      end
    end

    association_scope = association.scope

    associated_model = association.klass

    if association.macro == :belongs_to
      foreign_key = association.options[:primary_key] || self.primary_key
      primary_key = association.foreign_key
    else
      primary_key = association.options[:primary_key] || self.primary_key
      foreign_key = association.foreign_key
    end

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    associated_ids = quote_table_and_column_name(associated_model.table_name, foreign_key)

    result = associated_model.select("1").where("#{associated_ids} = #{self_ids}")

    if association.options[:as]
      other_types = quote_table_and_column_name(associated_model.table_name, association.type)
      class_values = [self.name, self.table_name]
      class_values << self.polymorphic_name if associated_model.respond_to?(:polymorphic_name)

      result = result.where("#{other_types} IN (?)", class_values.uniq)
    end

    if association_scope
      result = result.instance_exec(&association_scope)
    end

    if next_association[:association]
      return loop_nested_association(result, next_association, &block)
    end

    if where_parameters != []
      result = result.where(*where_parameters)
    end

    result = yield result if block_given?
    [result]
  end

  def where_exists_for_habtm_query(association, where_parameters, next_association = {}, &block)
    association_scope = association.scope

    associated_model = association.klass

    primary_key = association.options[:primary_key] || self.primary_key

    self_ids = quote_table_and_column_name(self.table_name, primary_key)
    join_ids = quote_table_and_column_name(association.join_table, association.foreign_key)
    associated_join_ids = quote_table_and_column_name(association.join_table, association.association_foreign_key)
    associated_ids = quote_table_and_column_name(associated_model.table_name, associated_model.primary_key)

    result =
      associated_model.
      select("1").
      joins(
        <<-SQL
          INNER JOIN #{connection.quote_table_name(association.join_table)}
          ON #{associated_ids} = #{associated_join_ids}
        SQL
      ).
      where("#{join_ids} = #{self_ids}")

    if next_association[:association]
      return loop_nested_association(result, next_association, &block)
    end

    if where_parameters != []
      result = result.where(*where_parameters)
    end

    if association_scope
      result = result.instance_exec(&association_scope)
    end

    result = yield result if block_given?

    [result]
  end

  def loop_nested_association(query, next_association = {}, nested = false, &block)
    scope = next_association[:scope] || -> { self }
    block ||= ->(it) { it }
    block_with_scope =
      lambda do |it|
        block.call(it.instance_exec(&scope))
      end
    str = query.klass.build_exists_string(
      next_association[:association].name,
      *[
        *next_association[:params]
      ].compact,
      &block_with_scope
    )

    if next_association[:next_association] && next_association[:next_association][:association]
      subq = str.match(/\([^\(\)]+\)/mi)[0]
      str.sub!(subq) do
        "(#{subq} AND (#{loop_nested_association(
          next_association[:association],
          next_association[:next_association],
          true,
          &block_with_scope
        )}))"
      end
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
