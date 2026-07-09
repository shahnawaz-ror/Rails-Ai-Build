# Go-to-Market Playbook — "Forgot Cursor?"

**Target persona:** Rails developer, 3–10 years experience, uses RubyMine or VS Code without Cursor, works at a startup or agency.

---

## The Hook

### Headline options (A/B test on landing page)

1. **"Forgot Cursor? Add AI to your Rails app in 5 minutes."**
2. **"Cursor lives in your editor. We live in your Rails app."**
3. **"The AI agent your whole Rails team shares — not just your laptop."**
4. **"gem 'rails_ai_build' — that's it. You're done."**

### 5-minute wow demo (record this first)

```bash
# Terminal recording — no cuts, real time
gem install rails_ai_build
rails generate rails_ai_build:install
rails db:migrate

export OPENAI_API_KEY=sk-...

rails rails_ai_build:ask["Add a /health endpoint that returns JSON status ok"]

# Show: agent reads routes.rb → writes change → runs test → done
```

**Post everywhere:** YouTube, Twitter/X, r/rails, Dev.to, Ruby Weekly.

---

## Launch Sequence (30 days)

### Week 1: Seed
| Day | Action |
|-----|--------|
| Mon | Publish gem to RubyGems |
| Tue | Launch railsaibuild.com with waitlist |
| Wed | Dev.to: "I built a Cursor alternative inside Rails" |
| Thu | r/rails post + Hacker News (Show HN) |
| Fri | Email Ruby Weekly submission |

### Week 2: Content
| Day | Action |
|-----|--------|
| Mon | Blog: "5 things Rails AI can do that Cursor can't" |
| Tue | YouTube demo #1: CRUD in 60 seconds |
| Wed | YouTube demo #2: Add RSpec tests automatically |
| Thu | Guest post on Rails Changelog |
| Fri | Twitter thread: architecture breakdown |

### Week 3: Agencies
| Day | Action |
|-----|--------|
| Mon | List 50 Rails agencies (thoughtbot, Planet Argon, etc.) |
| Tue–Thu | Cold email: "Free AI for your next client project" |
| Fri | Onboard 3 design partner agencies |

### Week 4: Convert
| Day | Action |
|-----|--------|
| Mon | Announce Cloud beta to waitlist |
| Tue | First 20 beta users get 3 months free |
| Wed | Case study from design partner |
| Thu | Product Hunt launch |
| Fri | Review metrics, iterate |

---

## Content Calendar (ongoing)

| Format | Frequency | Topic examples |
|--------|-----------|----------------|
| Short demo GIF | 2x/week | One feature in 30 seconds |
| Blog post | 1x/week | Tutorials, comparisons, case studies |
| YouTube | 2x/month | Deep dives, live coding |
| Newsletter | 1x/month | Changelog + tips |
| Podcast guest | 1x/month | Riding Ruby, Remote Ruby, etc. |

### High-performing post ideas

1. "I replaced Cursor with a Rails gem — here's what happened"
2. "Add an AI admin panel to your Rails app in 10 lines"
3. "How our agency ships client features 3x faster with rails_ai_build"
4. "Rails AI vs Cursor: when to use which"
5. "Self-hosted AI coding agents for regulated industries"

---

## Agency Sales Script

**Subject:** Free AI coding agent for [Agency Name]'s Rails projects

> Hi [Name],
>
> I built an open-source gem that adds Cursor-like AI agents directly into Rails apps — no IDE switch required.
>
> Agencies like yours are using it to:
> - Scaffold CRUD features in minutes instead of hours
> - Auto-generate RSpec tests for client deliverables  
> - Give junior devs a senior Rails mentor built-in
>
> I'd love to set up [Agency Name] as a design partner — free Team plan for 90 days in exchange for feedback and a case study.
>
> 15-minute call this week?
>
> [Demo video link]

**Conversion target:** 10% reply rate → 5 agencies from 50 outreach.

---

## Enterprise Sales Script

**Target:** VP Engineering at fintech/healthcare with Rails monolith.

> Your team can't send code to Cursor's cloud. We deploy inside your VPC.
>
> - Self-hosted AI agents on your infrastructure
> - Audit log of every AI-initiated code change
> - SSO + RBAC — control who can run what
> - Works with RubyMine, existing GitLab, existing CI
>
> [Bank X] reduced feature delivery time 40% while keeping code on-prem.

---

## Pricing Psychology

| Plan | Price | Anchor |
|------|-------|--------|
| Free | $0 | "Try it forever" |
| Pro | $29/mo | "Less than Cursor ($20) + Rails-native" |
| Team | $99/seat/mo | "Less than one hour of dev time" |
| Enterprise | $2K+/mo | "Less than one bad hire" |

**Never compete on price with Cursor.** Compete on Rails depth + team features + self-host.

---

## Metrics Dashboard

| Metric | Week 1 target | Month 3 target |
|--------|---------------|----------------|
| Gem installs | 500 | 5,000 |
| GitHub stars | 100 | 1,000 |
| Waitlist signups | 200 | 2,000 |
| Weekly active devs | 50 | 500 |
| Paying customers | 0 | 50 |
| MRR | $0 | $5,000 |

---

## Community Building

| Channel | Purpose |
|---------|---------|
| Discord server | Support + agent sharing |
| GitHub Discussions | Feature requests |
| Monthly "Rails AI Office Hours" | Live Q&A, build in public |
| "Agent of the Week" | Showcase community agents |
| Rails AI Certified Developer | Paid certification ($499) |

---

## The Million-Dollar Mindset

```
Year 1:  Be the gem every Rails dev tries     →  distribution
Year 2:  Be the cloud every Rails team pays   →  $1M ARR  
Year 3:  Be the platform every agency runs on →  $3M+ ARR
Year 5:  Be acquired by GitLab, HashiCorp,    →  exit
         or Shopify — or raise Series A
```

**The gem is not the product. The gem is the distribution channel for a platform company.**
