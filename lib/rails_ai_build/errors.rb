# frozen_string_literal: true

module RailsAiBuild
  class Error < StandardError; end
  class ProviderError < Error; end
  class AgentError < Error; end
  class ToolError < Error; end
  class ConfigurationError < Error; end
  class SecurityError < Error; end
  class CancelledError < Error; end
end
