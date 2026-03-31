class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_local_or_auth

  private

  # 本番では Basic 認証でアクセス制限
  # ADMIN_PASSWORD 環境変数が設定されている場合は認証を要求
  def require_local_or_auth
    password = ENV["ADMIN_PASSWORD"]
    return unless password.present?

    authenticate_or_request_with_http_basic("AI Trading Admin") do |_, pw|
      ActiveSupport::SecurityUtils.secure_compare(pw, password)
    end
  end
end
