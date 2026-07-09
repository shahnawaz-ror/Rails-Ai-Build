# frozen_string_literal: true

module RailsAiBuild
  module Agents
    Message = Struct.new(:role, :content, :tool_calls, :tool_call_id, :name, keyword_init: true) do
      def to_h
        h = { role: role, content: content }
        h[:tool_calls] = tool_calls if tool_calls
        h[:tool_call_id] = tool_call_id if tool_call_id
        h[:name] = name if name
        h
      end

      def self.user(content)
        new(role: :user, content: content)
      end

      def self.system(content)
        new(role: :system, content: content)
      end

      def self.assistant(content, tool_calls: nil)
        new(role: :assistant, content: content, tool_calls: tool_calls)
      end

      def self.tool(content, tool_call_id:, name: nil)
        new(role: :tool, content: content, tool_call_id: tool_call_id, name: name)
      end
    end
  end
end
