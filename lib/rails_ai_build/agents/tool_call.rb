# frozen_string_literal: true

module RailsAiBuild
  module Agents
    ToolCall = Struct.new(:id, :name, :arguments, keyword_init: true) do
      def to_h
        { id: id, name: name, arguments: arguments }
      end
    end
  end
end
