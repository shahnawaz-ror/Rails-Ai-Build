# Enterprise Self-Hosted Guide

## Quick start

```bash
rails generate rails_ai_build:enterprise
docker compose -f docker-compose.rails-ai-build.yml up -d
```

## Configuration

```ruby
# config/initializers/rails_ai_build_enterprise.rb
RailsAiBuild.configure do |config|
  config.plan = :enterprise
  config.diff_preview = true
  config.audit_enabled = true
  config.rbac_enabled = true
  config.saml_enabled = true
end
```

## SSO/SAML

Set environment variables:
```
SAML_IDP_SSO_URL=https://your-idp.com/sso
SAML_IDP_CERT=...
SAML_ACS_URL=https://yourapp.com/auth/saml/callback
```

Get config snippet: `GET /rails_ai_build/auth/saml`

## RBAC roles

```ruby
RailsAiBuild::Rbac.configure_roles!(
  admin: %i[read_file write_file grep list_files shell],
  reviewer: %i[read_file grep list_files],
  viewer: %i[read_file list_files]
)
RailsAiBuild::Rbac.current_role = :reviewer
```

## Air-gapped deployment

1. Build Docker image on connected machine
2. Transfer image to air-gapped environment
3. Set `WORKSPACE_ROOT` to your Rails app path
4. Provide API keys via environment or internal LLM endpoint

## Support

Enterprise support: support@railsaibuild.com
