#!/usr/bin/env bash
# Generates a markdown coverage summary for PR comments from Cobertura XML files.
set -euo pipefail

parse_cobertura() {
  local file="$1"
  local label="$2"

  if [[ ! -f "$file" ]]; then
    echo "| ${label} | — | — | ⚠️ missing |"
    return
  fi

  local line_rate branch_rate line_pct branch_pct badge

  line_rate=$(grep -o 'line-rate="[0-9.]*"' "$file" | head -1 | cut -d'"' -f2)
  branch_rate=$(grep -o 'branch-rate="[0-9.]*"' "$file" | head -1 | cut -d'"' -f2)

  line_pct=$(awk -v r="${line_rate:-0}" 'BEGIN { printf "%.1f%%", r * 100 }')
  branch_pct=$(awk -v r="${branch_rate:-0}" 'BEGIN { printf "%.1f%%", r * 100 }')

  badge="🟢"
  awk -v r="${line_rate:-0}" 'BEGIN { exit (r >= 0.8) ? 0 : 1 }' || badge="🟡"
  awk -v r="${line_rate:-0}" 'BEGIN { exit (r >= 0.6) ? 0 : 1 }' || badge="🔴"

  echo "| ${label} | ${line_pct} | ${branch_pct} | ${badge} |"
}

RUBY_ROW=$(parse_cobertura "${RUBY_COBERTURA:-coverage/coverage.xml}" "Ruby gem")
PYTHON_ROW=$(parse_cobertura "${PYTHON_COBERTURA:-packages/python/coverage.xml}" "Python SDK")

cat <<MARKDOWN
## Test coverage report

| Package | Lines | Branches | Status |
|---------|-------|----------|--------|
${RUBY_ROW}
${PYTHON_ROW}

<details>
<summary>Coverage details</summary>

- **Ruby**: SimpleCov on \`lib/**\` + engine controllers (\`COVERAGE=true bundle exec rspec\`)
- **Python**: pytest-cov on \`packages/python/rails_ai_build\`
- HTML artifacts uploaded to workflow run

Thresholds: 🟢 ≥80% · 🟡 ≥60% · 🔴 <60%

</details>
MARKDOWN
