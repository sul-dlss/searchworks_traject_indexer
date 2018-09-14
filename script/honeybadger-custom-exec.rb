#!/usr/bin/env ruby

# Fork of honeybadger cli, with a small monkeypatch to Honeybadger::CLI::Exec to
# only check the process status code, not any STDERR heuristics.

require 'honeybadger/cli'
require 'honeybadger/cli/exec'

module Honeybadger
  module CLI
    class Exec
      def exec_cmd
        stdout, stderr, status = Open3.capture3(args.join(' '))

        success = status.success? # && stderr =~ BLANK
        pid = status.pid
        code = status.to_i
        msg = ERB.new(FAILED_TEMPLATE).result(binding) unless success

        OpenStruct.new(
          msg: msg,
          pid: pid,
          code: code,
          stdout: stdout,
          stderr: stderr,
          success: success
        )
      rescue Errno::EACCES, Errno::ENOEXEC
        OpenStruct.new(
          msg: ERB.new(NO_EXEC_TEMPLATE).result(binding),
          code: 126
        )
      rescue Errno::ENOENT
        OpenStruct.new(
          msg: ERB.new(NOT_FOUND_TEMPLATE).result(binding),
          code: 127
        )
      end
    end
  end
end

Honeybadger::CLI.start(ARGV)
