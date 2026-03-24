# frozen_string_literal: true

module Fastframe
  class Frame
    class << self
      def fields(*field_names)
        field_names.filter { |b| b.class.in?([String, Symbol]) }.each do |field_name|
          defined_fields << Field.new(field_name, {})
        end
      end

      def field(field_name, options = {}, &)
        defined_fields << Field.new(field_name, options, &)
      end

      def defined_fields
        @defined_fields ||= []
      end

      def defined_associations
        @defined_associations ||= []
      end

      def defined_conditions
        @defined_conditions ||= []
      end

      def association(name, options = {}, &block)
        defined_associations << Association.new(name, Class.new(Frame).tap { |b| b.class_exec(&block) }, options)
      end

      def condition(validation_entry, options = {}, &block)
        defined_conditions << Condition.new(validation_entry, Class.new(Frame).tap { |b| b.class_exec(&block) }, options)
      end

      def render_hash(entity, options = {})
        return unless entity

        if entity.respond_to?(:each)
          render_many_hash(entity, options)
        else
          hash = defined_fields.to_h do |field|
            [field.name, field.extract(entity)]
          end

          defined_associations.each_with_object(hash) do |association, hash|
            hash[association.name] = association.render(entity, options)
          end

          defined_conditions.each_with_object(hash) do |condition, hash|
            hash.merge!(condition.render(entity, options)) if condition.applies?(entity)
          end

          hash
        end
      end

      def render_json(renderable, root: :data)
        hash = {}.tap { |b| b[root] = render_hash(renderable) }

        Oj.dump(hash, mode: :rails)
      end

      alias render render_json

      def render_many_hash(enumerable, options = {})
        query = enumerable

        query = enumerable.preload(prepare_preload) if enumerable.respond_to?('preload') && !options[:skip_preload]

        query.map do |entity|
          render_hash(entity, options.merge(skip_preload: true))
        end
      end

      def prepare_preload
        hash = defined_associations.reduce({}) do |acc, association|
          acc.merge(association.prepare_preload)
        end

        defined_fields.reduce(hash) do |acc, field|
          acc.merge(field.prepare_preload)
        end
      end
    end
  end
end
