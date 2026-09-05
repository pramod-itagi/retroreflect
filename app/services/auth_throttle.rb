class AuthThrottle
  LOGIN_LIMIT = 10
  RESET_LIMIT = 5
  WINDOW = 15.minutes
  TOO_MANY_ATTEMPTS = "Too many attempts. Please try again later."

  class << self
    def blocked?(scope, ip)
      read(scope, ip) >= limit_for(scope)
    end

    def record!(scope, ip)
      key = cache_key(scope, ip)
      if Rails.cache.exist?(key)
        Rails.cache.increment(key)
      else
        Rails.cache.write(key, 1, expires_in: WINDOW)
      end
    end

    def reset!
      Rails.cache.clear
    end

    private

    def read(scope, ip)
      Rails.cache.read(cache_key(scope, ip)).to_i
    end

    def cache_key(scope, ip)
      "auth-throttle:#{scope}:#{ip}"
    end

    def limit_for(scope)
      scope.to_sym == :password_reset ? RESET_LIMIT : LOGIN_LIMIT
    end
  end
end
