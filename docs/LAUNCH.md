# Launch Checklist — Rails AI Build v2.3.0

**Activation OS + IDE intelligence shipped.** See [FLOWS.md](./FLOWS.md) Flow 0 and [CLIENT_JOURNEY_MASTER_PLAN.md](./CLIENT_JOURNEY_MASTER_PLAN.md).

## Distribution (Day 1)

- [ ] Set `RUBYGEMS_API_KEY` secret in GitHub → publish gem
- [ ] Set `PYPI_API_TOKEN` secret → publish Python package
- [ ] Set `NPM_TOKEN` secret → publish `@rails-ai-build/sdk`
- [x] Tag releases: v1.0.0 through v1.3.0 (next: v2.3.0)
- [ ] Enable GitHub Pages for landing site

## Activation / entitlements (Day 1)

- [ ] Set `RAILS_AI_BUILD_SECRET` or rely on Rails `secret_key_base` for encrypted keys
- [ ] Set `RAILS_AI_BUILD_LICENSE_SECRET` for signed license tokens (production)
- [ ] Optional: `RAILS_AI_BUILD_SETTINGS_TOKEN` for locked-down settings mutations
- [ ] Verify IDE wizard → Doctor green on a fresh Rails app

## Stripe (Week 1)

- [ ] Create Stripe account at stripe.com
- [ ] Create products: Pro ($29/mo), Team ($99/seat/mo)
- [ ] Set secrets: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- [ ] Set env: `STRIPE_PRICE_PRO`, `STRIPE_PRICE_TEAM`
- [ ] Confirm webhook `checkout.session.completed` persists plan via `Activation.apply_plan!`

## Marketing (Week 1)

- [ ] Deploy `landing/index.html` to railsaibuild.com
- [ ] Record 5-min demo: `rails rails_ai_build:setup`
- [ ] Submit to Ruby Weekly, Rails Changelog
- [ ] Post on r/rails, Dev.to, Hacker News
- [ ] Product Hunt launch

## Agency outreach (Week 2)

- [ ] Email 50 Rails agencies (template in docs/GTM_PLAYBOOK.md)
- [ ] Onboard 3 design partners with free Team plan
- [ ] Publish first case study

## Enterprise (Month 1)

- [ ] `rails generate rails_ai_build:enterprise` demo
- [ ] Docker self-hosted docs
- [ ] First enterprise pilot conversation

## Metrics to track

| Metric | Target (Month 1) |
|--------|------------------|
| Gem installs | 1,000 |
| GitHub stars | 100 |
| Waitlist signups | 200 |
| Paying customers | 10 |
| MRR | $500 |

## Quick commands

```bash
# Publish gem manually
gem build rails_ai_build.gemspec
gem push rails_ai_build-1.0.0.gem

# Run full test suite
bundle exec rspec
python3 -m pytest packages/python/tests/
cd packages/javascript && npm run build

# Generate everything in a Rails app
rails generate rails_ai_build:install
rails generate rails_ai_build:admin
rails generate rails_ai_build:ci
rails generate rails_ai_build:enterprise
rails rails_ai_build:setup
```
