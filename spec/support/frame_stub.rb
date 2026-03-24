# frozen_string_literal: true

module FrameStub
  def self.new(&block)
    Class.new(Fastframe::Frame).tap { |klass| klass.class_exec(&block) }
  end
end
