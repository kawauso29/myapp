module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Try JWT from query params
      token = request.params[:token]
      if token.present?
        user = authenticate_jwt(token)
        return user if user
      end

      # Allow unauthenticated connections for global timeline
      nil
    end

    def authenticate_jwt(token)
      secret = ENV.fetch("DEVISE_JWT_SECRET_KEY", Rails.application.secret_key_base)
      payload = JWT.decode(token, secret, true, algorithm: "HS256").first
      User.find_by(id: payload["sub"])
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end
end
