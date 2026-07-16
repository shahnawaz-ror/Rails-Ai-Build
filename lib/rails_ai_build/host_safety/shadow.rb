# frozen_string_literal: true

require "fileutils"
require "open3"
require "securerandom"

module RailsAiBuild
  module HostSafety
    # Phase C — Isolate: optional shadow worktree. Agent writes there; promote only when green.
    module Shadow
      module_function

      def enabled?
        RailsAiBuild.configuration.host_safety_shadow_worktree == true
      end

      def active_workspace
        Thread.current[:rails_ai_build_shadow_workspace]
      end

      def active_workspace=(path)
        Thread.current[:rails_ai_build_shadow_workspace] = path
      end

      def meta
        Thread.current[:rails_ai_build_shadow_meta]
      end

      def meta=(value)
        Thread.current[:rails_ai_build_shadow_meta] = value
      end

      # Returns shadow Pathname when enabled, else original workspace.
      def prepare!(session_id, workspace:)
        return workspace unless enabled?

        root = Pathname(workspace)
        shadow_root = root.join(".rails_ai_build", "shadow", session_id.to_s)
        FileUtils.rm_rf(shadow_root) if shadow_root.exist?
        shadow_root.dirname.mkpath

        info =
          if git_repo?(root)
            add_worktree!(root, shadow_root, session_id)
          else
            copy_tree!(root, shadow_root)
          end

        self.meta = info.merge(session_id: session_id, original: root.to_s, shadow: shadow_root.to_s)
        self.active_workspace = shadow_root
        Audit.log(action: "host_safety.isolate", metadata: meta.slice(:session_id, :mode, :shadow))
        shadow_root
      rescue StandardError => e
        Audit.log(action: "host_safety.isolate_failed", metadata: { error: e.message, session_id: session_id })
        self.meta = nil
        self.active_workspace = nil
        workspace
      end

      def promote!(session_id = nil)
        info = meta
        return { ok: false, reason: "no_shadow" } unless info
        return { ok: false, reason: "session_mismatch" } if session_id && info[:session_id].to_s != session_id.to_s

        original = Pathname(info[:original])
        shadow = Pathname(info[:shadow])
        paths = Changes::Store.session_paths(info[:session_id])
        promoted = []

        paths.each do |rel|
          src = shadow.join(rel)
          dest = original.join(rel)
          next unless src.file?

          dest.dirname.mkpath
          FileUtils.cp(src.to_s, dest.to_s)
          promoted << rel
        end

        cleanup!(keep_meta: false)
        Audit.log(action: "host_safety.promote", metadata: { session_id: info[:session_id], count: promoted.size })
        { ok: true, promoted: promoted, count: promoted.size }
      end

      def discard!(session_id = nil)
        info = meta
        return { ok: false, reason: "no_shadow" } unless info
        return { ok: false, reason: "session_mismatch" } if session_id && info[:session_id].to_s != session_id.to_s

        cleanup!(keep_meta: false)
        Audit.log(action: "host_safety.discard", metadata: { session_id: info[:session_id] })
        { ok: true, discarded: true }
      end

      def cleanup!(keep_meta: false)
        info = meta
        if info
          shadow = Pathname(info[:shadow])
          original = Pathname(info[:original])
          if info[:mode] == :worktree && git_repo?(original)
            Open3.capture2e("git", "worktree", "remove", "--force", shadow.to_s, chdir: original.to_s)
          end
          FileUtils.rm_rf(shadow) if shadow.exist?
        end
        self.active_workspace = nil
        self.meta = nil unless keep_meta
      end

      def add_worktree!(root, shadow_root, session_id)
        branch = "rab-shadow-#{session_id.to_s[0, 12]}-#{SecureRandom.hex(3)}"
        out, status = Open3.capture2e(
          "git", "worktree", "add", "-b", branch, shadow_root.to_s, "HEAD",
          chdir: root.to_s
        )
        raise "git worktree add failed: #{out}" unless status.success?

        { mode: :worktree, branch: branch }
      end

      def copy_tree!(root, shadow_root)
        FileUtils.mkdir_p(shadow_root)
        Dir.children(root).each do |entry|
          next if %w[.git .rails_ai_build tmp log node_modules vendor/bundle].include?(entry)

          src = root.join(entry)
          FileUtils.cp_r(src.to_s, shadow_root.join(entry).to_s)
        end
        { mode: :copy }
      end

      def git_repo?(workspace)
        workspace.join(".git").exist? || system("git", "-C", workspace.to_s, "rev-parse", "--is-inside-work-tree",
                                               out: File::NULL, err: File::NULL)
      end
    end
  end
end
