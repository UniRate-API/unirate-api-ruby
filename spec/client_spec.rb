# frozen_string_literal: true

require "spec_helper"

RSpec.describe UniRate::Client do
  let(:api_key) { "test-key" }
  let(:client)  { described_class.new(api_key: api_key) }
  let(:base)    { "https://api.unirateapi.com" }

  # Helper: assert request query params contain the expected pairs.
  def expect_query(request, expected)
    query = Hash[URI.decode_www_form(request.uri.query || "")]
    expected.each do |key, value|
      expect(query[key.to_s]).to eq(value.to_s),
                                 "expected query #{key}=#{value}, got #{query[key.to_s].inspect}"
    end
  end

  describe "#get_rate" do
    it "fetches a single exchange rate and upcases codes" do
      stub = stub_request(:get, "#{base}/api/rates")
             .with(query: hash_including("from" => "USD", "to" => "EUR", "api_key" => api_key))
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: { rate: "0.9321" }.to_json
             )

      rate = client.get_rate(from: "usd", to: "eur")
      expect(rate).to be_within(0.0001).of(0.9321)
      expect(stub).to have_been_requested
    end

    it "returns a Hash of all rates when `to` is omitted" do
      stub_request(:get, "#{base}/api/rates")
        .with(query: hash_including("from" => "USD", "api_key" => api_key))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { rates: { "EUR" => "0.9", "GBP" => "0.8" } }.to_json
        )

      rates = client.get_rate(from: "USD")
      expect(rates).to eq("EUR" => 0.9, "GBP" => 0.8)
    end

    it "sends the Accept: application/json header" do
      stub = stub_request(:get, "#{base}/api/rates")
             .with(
               query: hash_including("api_key" => api_key),
               headers: { "Accept" => "application/json" }
             )
             .to_return(status: 200, body: { rate: "1.0" }.to_json)

      client.get_rate(to: "EUR")
      expect(stub).to have_been_requested
    end
  end

  describe "#convert" do
    it "returns the converted Float amount" do
      stub_request(:get, "#{base}/api/convert")
        .with(query: hash_including("amount" => "100", "from" => "USD", "to" => "EUR"))
        .to_return(status: 200, body: { result: "93.21" }.to_json)

      amount = client.convert(amount: 100, from: "USD", to: "EUR")
      expect(amount).to be_within(0.01).of(93.21)
    end
  end

  describe "#get_supported_currencies" do
    it "returns the currency list" do
      stub_request(:get, "#{base}/api/currencies")
        .with(query: { "api_key" => api_key })
        .to_return(status: 200, body: { currencies: %w[USD EUR GBP BTC] }.to_json)

      expect(client.get_supported_currencies).to eq(%w[USD EUR GBP BTC])
    end
  end

  describe "#get_historical_rate" do
    it "returns a single rate when `to` is set and amount == 1" do
      stub_request(:get, "#{base}/api/historical/rates")
        .with(query: hash_including("date" => "2024-01-01", "from" => "USD", "to" => "EUR", "amount" => "1"))
        .to_return(status: 200, body: { rate: "0.8412" }.to_json)

      rate = client.get_historical_rate(date: "2024-01-01", from: "USD", to: "EUR")
      expect(rate).to be_within(0.0001).of(0.8412)
    end
  end

  describe "#get_time_series" do
    it "joins currencies with commas and returns the data map" do
      stub_request(:get, "#{base}/api/historical/timeseries")
        .with(query: hash_including(
          "start_date" => "2024-01-01",
          "end_date"   => "2024-01-02",
          "base"       => "USD",
          "currencies" => "EUR"
        ))
        .to_return(
          status: 200,
          body: { data: { "2024-01-01" => { "EUR" => 0.90 }, "2024-01-02" => { "EUR" => 0.91 } } }.to_json
        )

      series = client.get_time_series(
        start_date: "2024-01-01",
        end_date:   "2024-01-02",
        base:       "USD",
        currencies: ["EUR"]
      )

      expect(series["2024-01-01"]["EUR"]).to eq(0.90)
      expect(series["2024-01-02"]["EUR"]).to eq(0.91)
    end
  end

  describe "#get_historical_limits" do
    it "returns the raw limits hash" do
      stub_request(:get, "#{base}/api/historical/limits")
        .with(query: { "api_key" => api_key })
        .to_return(status: 200, body: {
          total_currencies: 2,
          currencies: {
            "USD" => { "earliest_date" => "1999-01-01", "latest_date" => "2026-04-20" },
            "EUR" => { "earliest_date" => "1999-01-01", "latest_date" => "2026-04-20" }
          }
        }.to_json)

      limits = client.get_historical_limits
      expect(limits["total_currencies"]).to eq(2)
      expect(limits["currencies"]["USD"]["earliest_date"]).to eq("1999-01-01")
    end
  end

  describe "#get_vat_rates" do
    it "returns VAT data for a single country (upcased)" do
      stub_request(:get, "#{base}/api/vat/rates")
        .with(query: hash_including("country" => "DE", "api_key" => api_key))
        .to_return(status: 200, body: {
          country: "DE",
          vat_data: { country_code: "DE", country_name: "Germany", vat_rate: 19.0 }
        }.to_json)

      resp = client.get_vat_rates(country: "de")
      expect(resp["country"]).to eq("DE")
      expect(resp["vat_data"]["vat_rate"]).to eq(19.0)
    end

    it "returns all countries when `country` is omitted" do
      stub_request(:get, "#{base}/api/vat/rates")
        .with(query: { "api_key" => api_key })
        .to_return(status: 200, body: {
          date: "2026-01-22",
          total_countries: 2,
          vat_rates: {
            "DE" => { "country_code" => "DE", "country_name" => "Germany", "vat_rate" => 19.0 },
            "FR" => { "country_code" => "FR", "country_name" => "France",  "vat_rate" => 20.0 }
          }
        }.to_json)

      resp = client.get_vat_rates
      expect(resp["total_countries"]).to eq(2)
      expect(resp["vat_rates"]["DE"]["vat_rate"]).to eq(19.0)
      expect(resp["vat_rates"]["FR"]["country_name"]).to eq("France")
    end
  end

  describe "error mapping" do
    it "raises ApiError(403) for Pro-gated endpoints on free tier" do
      stub_request(:get, "#{base}/api/historical/rates")
        .with(query: hash_including("api_key" => api_key))
        .to_return(status: 403, body: { error: "Historical data access requires a Pro subscription" }.to_json)

      expect {
        client.get_historical_rate(date: "2024-01-01", from: "USD", to: "EUR")
      }.to raise_error(UniRate::ApiError) { |e|
        expect(e.status_code).to eq(403)
        expect(e.response).to include("Pro subscription")
      }
    end

    it "raises AuthenticationError on 401" do
      stub_request(:get, "#{base}/api/rates")
        .with(query: hash_including("api_key" => api_key))
        .to_return(status: 401, body: "")
      expect { client.get_rate(to: "EUR") }.to raise_error(UniRate::AuthenticationError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, "#{base}/api/rates")
        .with(query: hash_including("api_key" => api_key))
        .to_return(status: 429, body: "")
      expect { client.get_rate(to: "EUR") }.to raise_error(UniRate::RateLimitError)
    end

    it "raises InvalidCurrencyError on 404" do
      stub_request(:get, "#{base}/api/rates")
        .with(query: hash_including("api_key" => api_key))
        .to_return(status: 404, body: "")
      expect { client.get_rate(to: "ZZZ") }.to raise_error(UniRate::InvalidCurrencyError)
    end
  end

  describe "authentication wiring" do
    it "always sends the api_key query parameter" do
      stub = stub_request(:get, "#{base}/api/currencies")
             .with(query: hash_including("api_key" => api_key))
             .to_return(status: 200, body: { currencies: [] }.to_json)

      client.get_supported_currencies
      expect(stub).to have_been_requested
    end
  end
end
