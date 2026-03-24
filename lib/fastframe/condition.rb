# frozen_string_literal: true

module Fastframe
  class Condition
    attr_reader :validation_entry, :frame, :options

    def initialize(validation_entry, frame, options)
      @validation_entry = validation_entry
      @frame = frame
      @options = options
    end

    def applies?(entity)
      case @validation_entry
      when Class
        entity.is_a?(@validation_entry)
      when Symbol
        entity.send(@validation_entry)
      when Proc
        @validation_entry.call(entity)
      end
    end

    def render(entity, options = {})
      frame.render_hash(entity, options)
    end

    def prepare_preload
      {}
    end
  end
end
