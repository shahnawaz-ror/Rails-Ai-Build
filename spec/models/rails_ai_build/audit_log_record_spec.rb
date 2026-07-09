# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::AuditLogRecord do
  it 'persists audit entries' do
    log = build_audit_log(action: 'write_file', path: 'app/models/post.rb')
    expect(log.reload.action).to eq('write_file')
    expect(log.path).to eq('app/models/post.rb')
  end
end
