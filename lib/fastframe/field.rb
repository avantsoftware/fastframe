# frozen_string_literal: true

module Fastframe
  class Field
    attr_reader :name, :options, :block

    def initialize(name, options, &block)
      @name = name
      @options = options
      @block = block
    end

    def relation_name
      final_name = @options[:as]

      final_name ||= name
      final_name = @options[:eager_loads] if @options[:eager_loads]&.class&.in?([String, Symbol])

      final_name.to_sym
    end

    def prepare_preload
      eager = @options[:eager_loads]
      return {} unless eager

      return eager if eager.is_a?(Hash)

      { relation_name => {} }
    end

    def extract(entity)
      if @block.present?
        @block.call(entity)
      else
        entity.send(@options[:from] || name)
      end
    end
  end
end
