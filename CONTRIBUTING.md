# Contributing to rails_ai_build

Thank you for helping improve **rails_ai_build**. This gem follows standard Ruby/Rails open-source practices.

## Development setup

```bash
git clone https://github.com/shahnawaz-ror/Rails-Ai-Build.git
cd Rails-Ai-Build
bin/setup
```

## Running checks

```bash
bundle exec rake          # RuboCop + full RSpec suite
bundle exec rubocop       # Style only
bundle exec rspec         # Tests only
bundle exec appraisal rake spec  # Multi-Rails matrix
```

## Code style

- Follow `.rubocop.yml` (RuboCop, rubocop-rails, rubocop-rspec, rubocop-performance)
- Use `# frozen_string_literal: true` in all Ruby files
- Keep changes focused; match existing patterns in `lib/` and `app/`

## Testing

| Layer | Location | Notes |
|-------|----------|-------|
| Unit | `spec/rails_ai_build/` | No full Rails boot |
| Request | `spec/requests/` | Combustion app in `spec/internal/` |
| Generators | `spec/generators/` | Rails generator test case |

Add specs for new features. Request specs are preferred for engine HTTP endpoints.

## Pull requests

1. Branch from `main`
2. Add tests and changelog entry under `[Unreleased]` or the next version
3. Ensure `bundle exec rake` passes locally
4. Open a PR with a clear description of behavior changes

## Release process (maintainers)

1. Bump `lib/rails_ai_build/version.rb` and `CHANGELOG.md`
2. Tag `vX.Y.Z` and push — GitHub Actions publishes to RubyGems, PyPI, and npm

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.
