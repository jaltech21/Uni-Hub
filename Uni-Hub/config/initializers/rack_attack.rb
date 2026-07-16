# Rate limits for the mobile JSON API. The web app (cookie-session) is not
# throttled here. Limits mirror PHASE_0_2_API_SCHEMA_DESIGN.md §11.

class Rack::Attack
  # Skip throttles entirely in the test environment so request specs are stable.
  Rack::Attack.enabled = !Rails.env.test?

  # 5 attempts per 15 minutes per IP on login/register
  throttle("api/v1/auth/credentials", limit: 5, period: 15.minutes) do |req|
    if req.path.start_with?("/api/v1/auth/login", "/api/v1/auth/register") && req.post?
      req.ip
    end
  end

  # 100 requests / minute / IP for the rest of the API
  throttle("api/v1/general", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/v1") && !req.path.start_with?("/api/v1/auth")
  end

  self.throttled_responder = lambda do |request|
    match = request.env["rack.attack.match_data"] || {}
    retry_after = match[:period].to_i
    headers = {
      "Content-Type"          => "application/json",
      "Retry-After"           => retry_after.to_s,
      "X-RateLimit-Limit"     => match[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset"     => (Time.current.to_i + retry_after).to_s
    }
    body = {
      success: false,
      error: { status: 429, message: "Too many requests", code: "RATE_LIMITED" }
    }.to_json
    [429, headers, [body]]
  end
end
