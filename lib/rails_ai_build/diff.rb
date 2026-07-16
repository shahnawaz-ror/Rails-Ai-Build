# frozen_string_literal: true

module RailsAiBuild
  module Diff
    module_function

    def compute(old_content, new_content, path:)
      old_lines = old_content.to_s.lines(chomp: true)
      new_lines = new_content.to_s.lines(chomp: true)

      # Do not embed full file bodies in the diff hash — PendingChange already holds them.
      {
        path: path,
        unified: unified_diff(old_lines, new_lines, path),
        stats: {
          additions: count_additions(old_lines, new_lines),
          deletions: count_deletions(old_lines, new_lines),
          changed: old_lines != new_lines
        }
      }
    end

    def unified_diff(old_lines, new_lines, path)
      header = "--- a/#{path}\n+++ b/#{path}\n"
      body = []

      old_lines.each_with_index do |line, i|
        body << "-#{line}" if new_lines[i] != line
      end
      new_lines.each_with_index do |line, i|
        body << "+#{line}" if old_lines[i] != line
      end

      if body.empty? && old_lines.length != new_lines.length
        body = ["-#{old_lines.join("\n")}", "+#{new_lines.join("\n")}"]
      end

      header + body.join("\n")
    end

    def count_additions(old_lines, new_lines)
      new_lines.each_with_index.count { |line, i| old_lines[i] != line }
    end

    def count_deletions(old_lines, new_lines)
      old_lines.each_with_index.count { |line, i| new_lines[i] != line }
    end
  end
end
