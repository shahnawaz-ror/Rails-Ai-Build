# frozen_string_literal: true

# Per-adapter CI gems — set INSTALL_CI_DB=postgresql or mysql2
case ENV["INSTALL_CI_DB"]
when "postgresql"
  gem "pg", "~> 1.5"
when "mysql2"
  gem "mysql2", "~> 0.5"
end
