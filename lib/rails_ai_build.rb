# frozen_string_literal: true

require "rails_ai_build/version"
require "rails_ai_build/configuration"
require "rails_ai_build/errors"

require "rails_ai_build/models/base_provider"
require "rails_ai_build/models/openai_provider"
require "rails_ai_build/models/anthropic_provider"
require "rails_ai_build/models/custom_provider"
require "rails_ai_build/models/registry"

require "rails_ai_build/tools/base_tool"
require "rails_ai_build/tools/read_file_tool"
require "rails_ai_build/tools/write_file_tool"
require "rails_ai_build/tools/grep_tool"
require "rails_ai_build/tools/list_files_tool"
require "rails_ai_build/tools/shell_tool"
require "rails_ai_build/tools/registry"

require "rails_ai_build/agents/message"
require "rails_ai_build/agents/tool_call"
require "rails_ai_build/agents/agent"
require "rails_ai_build/agents/runner"

require "rails_ai_build/chat_service"

require "rails_ai_build/diff"
require "rails_ai_build/plans"
require "rails_ai_build/audit"
require "rails_ai_build/changes/store"
require "rails_ai_build/skills/registry"
require "rails_ai_build/billing/client"

require "rails_ai_build/memory/store"
require "rails_ai_build/marketplace/registry"
require "rails_ai_build/integrations/pull_request"

require "rails_ai_build/cloud/client"
require "rails_ai_build/analytics"
require "rails_ai_build/rbac"
require "rails_ai_build/auth/saml"
require "rails_ai_build/bots/slack"

require "rails_ai_build/token_usage"
require "rails_ai_build/support"
require "rails_ai_build/upgrade"
require "rails_ai_build/compatibility/checker"
require "rails_ai_build/compatibility/catalog"
require "rails_ai_build/compatibility/fixtures"
require "rails_ai_build/compatibility/edge_cases"

require "rails_ai_build/streaming/sse"
require "rails_ai_build/demo/replayer"
require "rails_ai_build/integrations/git"
require "rails_ai_build/mcp/server"
require "rails_ai_build/orchestration/coordinator"
require "rails_ai_build/notifications/slack"

require "rails_ai_build/engine" if defined?(Rails)

module RailsAiBuild
  Providers = Models::Providers
end
