# frozen_string_literal: true

module GitHelpers
  def init_git_repo(path)
    Dir.chdir(path) do
      system('git init -q', exception: true)
      system('git config user.email test@example.com', exception: true)
      system('git config user.name Test', exception: true)
      File.write('README.md', "# test\n")
      system('git add .', exception: true)
      system('git commit -qm init', exception: true)
    end
  end
end

RSpec.configure do |config|
  config.include GitHelpers
end
