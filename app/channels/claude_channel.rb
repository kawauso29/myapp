# frozen_string_literal: true

require "pty"
require "timeout"

class ClaudeChannel < ApplicationCable::Channel
  def subscribed
    @mutex = Mutex.new
    start_claude_process
  end

  def unsubscribed
    stop_claude_process
  end

  def input(data)
    @mutex.synchronize do
      @master&.write(data["text"])
    end
  rescue Errno::EIO
    nil
  end

  def resize(data)
    return unless @master

    rows = data["rows"].to_i.clamp(1, 300)
    cols = data["cols"].to_i.clamp(1, 500)
    @master.winsize = [ rows, cols ]
  rescue StandardError
    nil
  end

  private

  def start_claude_process
    working_dir = ENV["CLAUDE_WORKING_DIR"].presence || Rails.root.to_s
    working_dir = Rails.root.to_s unless Dir.exist?(working_dir)
    claude_bin  = ENV["CLAUDE_BIN"].presence || `which claude`.strip
    env = { "TERM" => "xterm-256color", "COLORTERM" => "truecolor", "HOME" => Dir.home }

    Dir.chdir(working_dir) do
      @master, @slave, @pid = PTY.spawn(env, claude_bin, "--dangerously-skip-permissions")
    end

    @read_thread = Thread.new do
      begin
        loop do
          data = @master.readpartial(4096)
          transmit({ type: "output", data: data })
        end
      rescue Errno::EIO, EOFError, IOError
        transmit({ type: "exit" })
      rescue => e
        Rails.logger.error("ClaudeChannel PTY error: #{e.message}")
        transmit({ type: "error", message: e.message })
      end
    end
  rescue => e
    Rails.logger.error("ClaudeChannel spawn error: #{e.message}")
    transmit({ type: "error", message: "Failed to start Claude: #{e.message}" })
  end

  def stop_claude_process
    @read_thread&.kill
    @read_thread&.join(2)

    if @pid
      begin
        Process.kill("TERM", @pid)
        Timeout.timeout(3) { Process.wait(@pid) }
      rescue Errno::ESRCH, Errno::ECHILD, Timeout::Error
        Process.kill("KILL", @pid) rescue nil
      end
    end

    @master&.close rescue nil
    @slave&.close rescue nil
    @pid = nil
  end
end
