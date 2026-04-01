# Be sure to restart your server when you modify this file.

# Rack::Cors configuration for API access control.
# The global wildcard config in application.rb is overridden here
# for production to restrict origins to the app domain only.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.production?
      origins ENV.fetch("APP_DOMAIN", "localhost")
    else
      origins "*"
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
