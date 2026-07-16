# Allow the mobile app (and any approved web origin) to call the JSON API.
# Web (Hotwire) traffic is same-origin and uses cookie auth, so CORS only
# needs to cover /api/v1/* requests authenticated via Authorization: Bearer.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("API_ALLOWED_ORIGINS", "*").split(",").map(&:strip)

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: %w[Authorization X-RateLimit-Limit X-RateLimit-Remaining X-RateLimit-Reset],
      credentials: false
  end
end
