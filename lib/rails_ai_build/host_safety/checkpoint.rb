# frozen_string_literal: true

require "open3"

module RailsAiBuild
  module HostSafety
    # Optional git stash create before a turn — survives process restart better than memory-only.
    module Checkpoint
      module_function

      def create!(session_id, workspace:)
        return { ok: false, reason: "disabled" } unless RailsAiBuild.configuration.host_safety_git_checkpoint != false
        return { ok: false, reason: "not_a_git_repo" } unless git_repo?(workspace)

        out, status = Open3.capture2e("git", "stash", "create", chdir: workspace.to_s)
        ref = out.to_s.strip
        return { ok: false, reason: "empty_or_failed", output: ref } unless status.success? && ref.match?(/\A[0-9a-f]{7,40}\z/)

        store[session_id.to_s] = { ref: ref, workspace: workspace.to_s, created_at: Time.now }
        Audit.log(action: "host_safety.checkpoint", metadata: { session_id: session_id, ref: ref })
        { ok: true, ref: ref }
      rescue StandardError => e
        { ok: false, reason: e.message }
      end

      def restore!(session_id, workspace: nil)
        entry = store[session_id.to_s]
        return { ok: false, reason: "no_checkpoint" } unless entry

        workspace = Pathname(workspace || entry[:workspace])
        ref = entry[:ref]
        out, status = Open3.capture2e("git", "checkout", ref, "--", ".", chdir: workspace.to_s)
        { ok: status.success?, ref: ref, output: out.to_s[-1000, 1000] }
      rescue StandardError => e
        { ok: false, reason: e.message }
      end

      def clear!(session_id = nil)
        if session_id
          store.delete(session_id.to_s)
        else
          store.clear
        end
      end

      def store
        @store ||= {}
      end

      def git_repo?(workspace)
        workspace.join(".git").exist? || system("git", "-C", workspace.to_s, "rev-parse", "--is-inside-work-tree",
                                               out: File::NULL, err: File::NULL)
      end
    end
  end
end
