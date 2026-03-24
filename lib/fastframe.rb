# frozen_string_literal: true

require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/object/blank"

require_relative "fastframe/version"
require_relative "fastframe/field"
require_relative "fastframe/association"
require_relative "fastframe/condition"
require_relative "fastframe/frame"

module Fastframe
  class Error < StandardError; end
end
