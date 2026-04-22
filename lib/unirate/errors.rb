# frozen_string_literal: true

module UniRate
  # Base error class for all UniRate client errors.
  class Error < StandardError; end

  # Raised when the API key is missing or invalid (HTTP 401).
  class AuthenticationError < Error; end

  # Raised when the rate limit has been exceeded (HTTP 429).
  class RateLimitError < Error; end

  # Raised when a currency code is unknown or has no data (HTTP 404).
  class InvalidCurrencyError < Error; end

  # Raised when request parameters are invalid, typically a bad date (HTTP 400).
  class InvalidDateError < Error; end

  # Raised for any other non-2xx HTTP response. Carries the status code and
  # the raw response body so callers can inspect them.
  class ApiError < Error
    attr_reader :status_code, :response

    def initialize(message, status_code:, response: nil)
      super(message)
      @status_code = status_code
      @response = response
    end
  end
end
