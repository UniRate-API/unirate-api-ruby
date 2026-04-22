# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require_relative "errors"
require_relative "version"

module UniRate
  # Client for the UniRate API (https://unirateapi.com).
  #
  # All methods are synchronous and raise subclasses of {UniRate::Error} on
  # non-2xx responses. See the README for the full surface.
  class Client
    DEFAULT_BASE_URL = "https://api.unirateapi.com"
    DEFAULT_TIMEOUT = 30

    attr_reader :api_key, :base_url, :timeout

    # @param api_key [String] API key issued at https://unirateapi.com
    # @param base_url [String] optional base URL override (for testing)
    # @param timeout [Integer, Float] per-request timeout in seconds
    def initialize(api_key:, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT)
      raise ArgumentError, "api_key is required" if api_key.nil? || api_key.empty?

      @api_key = api_key
      @base_url = base_url
      @timeout = timeout
    end

    # ------------------------------------------------------------------
    # Current rates & conversion
    # ------------------------------------------------------------------

    # Fetch an exchange rate. When +to+ is nil, returns all rates for the
    # base currency as +{ "EUR" => 0.92, ... }+.
    #
    # @return [Float, Hash{String=>Float}, String]
    def get_rate(from: "USD", to: nil, format: "json", callback: nil)
      params = { "from" => from.to_s.upcase }
      params["to"] = to.to_s.upcase if to

      body = request("/api/rates", params, format: format, callback: callback)
      return body if format != "json"

      if to
        body["rate"].to_f
      else
        body["rates"].each_with_object({}) { |(code, value), h| h[code] = value.to_f }
      end
    end

    # Convert +amount+ from +from+ to +to+ using the current rate.
    # @return [Float, String]
    def convert(to:, amount: 1, from: "USD", format: "json", callback: nil)
      params = {
        "amount" => amount,
        "from" => from.to_s.upcase,
        "to" => to.to_s.upcase
      }

      body = request("/api/convert", params, format: format, callback: callback)
      return body if format != "json"

      if body.key?("result")
        body["result"].to_f
      else
        body["results"].each_with_object({}) { |(code, value), h| h[code] = value.to_f }
      end
    end

    # List of supported currency codes.
    # @return [Array<String>, String]
    def get_supported_currencies(format: "json", callback: nil)
      body = request("/api/currencies", {}, format: format, callback: callback)
      return body if format != "json"

      body["currencies"]
    end

    # ------------------------------------------------------------------
    # Historical data (Pro-gated — 403 on free tier)
    # ------------------------------------------------------------------

    # Historical exchange rate for a date.
    #
    # Return shape mirrors the spec:
    #   * +to+ set, +amount+ == 1  -> Float (single rate)
    #   * +to+ set, +amount+ != 1  -> Float (converted amount)
    #   * +to+ nil, +amount+ == 1  -> Hash (all rates)
    #   * +to+ nil, +amount+ != 1  -> Hash (all converted amounts)
    #
    # @return [Float, Hash{String=>Float}, String]
    def get_historical_rate(date:, amount: 1, from: "USD", to: nil, format: "json", callback: nil)
      params = {
        "date" => date,
        "amount" => amount,
        "from" => from.to_s.upcase
      }
      params["to"] = to.to_s.upcase if to

      body = request("/api/historical/rates", params, format: format, callback: callback)
      return body if format != "json"

      if to
        amount == 1 ? body["rate"].to_f : body["result"].to_f
      else
        key = amount == 1 ? "rates" : "results"
        body[key].each_with_object({}) { |(code, value), h| h[code] = value.to_f }
      end
    end

    # Thin alias: historical rates for a base currency (no +to+).
    # @return [Hash{String=>Float}, String]
    def get_historical_rates(date:, amount: 1, base: "USD", format: "json", callback: nil)
      get_historical_rate(
        date: date, amount: amount, from: base, to: nil,
        format: format, callback: callback
      )
    end

    # Thin alias over {#get_historical_rate} that always returns a Float.
    # @return [Float, String]
    def convert_historical(amount:, from:, to:, date:, format: "json", callback: nil)
      get_historical_rate(
        date: date, amount: amount, from: from, to: to,
        format: format, callback: callback
      )
    end

    # Time series (up to 5 years).
    # Returns the +data+ map: +{ "2024-01-01" => { "EUR" => 0.92, ... }, ... }+.
    # @return [Hash{String=>Hash{String=>Float}}, String]
    def get_time_series(start_date:, end_date:, amount: 1, base: "USD", currencies: nil, format: "json", callback: nil)
      params = {
        "start_date" => start_date,
        "end_date" => end_date,
        "amount" => amount,
        "base" => base.to_s.upcase
      }
      params["currencies"] = currencies.map { |c| c.to_s.upcase }.join(",") if currencies && !currencies.empty?

      body = request("/api/historical/timeseries", params, format: format, callback: callback)
      return body if format != "json"

      body["data"]
    end

    # Available historical-data coverage per currency.
    # @return [Hash, String]
    def get_historical_limits(format: "json", callback: nil)
      request("/api/historical/limits", {}, format: format, callback: callback)
    end

    # ------------------------------------------------------------------
    # VAT
    # ------------------------------------------------------------------

    # VAT rates. Pass +country+ (ISO-3166 alpha-2) for a single country.
    # @return [Hash, String]
    def get_vat_rates(country: nil, format: "json", callback: nil)
      params = {}
      params["country"] = country.to_s.upcase if country

      request("/api/vat/rates", params, format: format, callback: callback)
    end

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    private

    def request(path, params, format:, callback:)
      uri = URI.parse(base_url)
      uri.path = path

      query = params.dup
      query["api_key"] = api_key
      query["format"] = format if format && format != "json"
      query["callback"] = callback if callback && format == "json"
      uri.query = URI.encode_www_form(query)

      req = Net::HTTP::Get.new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = "unirate-ruby/#{UniRate::VERSION}"

      response =
        begin
          Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: timeout,
            read_timeout: timeout
          ) do |http|
            http.request(req)
          end
        rescue StandardError => e
          raise Error, "Network error: #{e.message}"
        end

      handle_response(response, format: format)
    end

    def handle_response(response, format:)
      status = response.code.to_i
      body = response.body.to_s

      case status
      when 200..299
        return body if format != "json"

        begin
          JSON.parse(body)
        rescue JSON::ParserError => e
          raise Error, "Failed to parse JSON response: #{e.message}"
        end
      when 400
        raise InvalidDateError, "Invalid request parameters"
      when 401
        raise AuthenticationError, "Missing or invalid API key"
      when 403
        raise ApiError.new(
          "Endpoint requires a Pro subscription",
          status_code: 403,
          response: body
        )
      when 404
        raise InvalidCurrencyError, "Currency not found or no data available"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 503
        raise ApiError.new("Service unavailable", status_code: 503, response: body)
      else
        raise ApiError.new(
          "UniRate API error (status #{status}): #{body}",
          status_code: status,
          response: body
        )
      end
    end
  end
end
