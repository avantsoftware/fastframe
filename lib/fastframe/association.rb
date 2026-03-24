# frozen_string_literal: true

module Fastframe
  class Association
    attr_reader :name, :frame, :options

    def initialize(name, frame, options)
      @name = name
      @frame = frame
      @options = options
    end

    def relation_name
      final_name = @options[:as]

      final_name ||= name
      final_name = @options[:eager_loads] if @options[:eager_loads]&.class&.in?([String, Symbol])

      final_name.to_sym
    end

    def render(parent_entity, options = {})
      if @options[:from].respond_to?(:call)
        frame.render_hash(@options[:from].call(parent_entity), options)
      else
        frame.render_hash(parent_entity.send(@options[:from] || name), options)
      end
    end

    def prepare_preload
      below_preloads = frame.prepare_preload

      {}.tap do |hash|
        hash[@options[:from] || relation_name] = below_preloads if below_preloads.any? || @options[:eager_loads]
      end
    end
  end
end
