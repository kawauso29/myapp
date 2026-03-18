# frozen_string_literal: true

class ClaudeController < ApplicationController
  before_action :authenticate_claude

  def index
    session[:claude_verified] = true
  end

  private

  def authenticate_claude
    authenticate_or_request_with_http_basic("Claude Terminal") do |username, password|
      expected_user = ENV.fetch("CLAUDE_TERMINAL_USER", "admin")
      expected_pass = ENV["CLAUDE_TERMINAL_PASSWORD"]

      return false if expected_pass.blank?

      user_ok = ActiveSupport::SecurityUtils.secure_compare(username, expected_user)
      pass_ok = ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
      user_ok && pass_ok
    end
  end
end
