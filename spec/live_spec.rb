# frozen_string_literal: true

# Live integration tests that hit api.unirateapi.com.
#
# Automatically skipped unless UNIRATE_API_KEY is set:
#
#   UNIRATE_API_KEY=your-key bundle exec rspec spec/live_spec.rb
#
# These tests only exercise the endpoints accessible on a free-tier key.
# Pro-gated endpoints (historical rates/timeseries/limits) surface as
# UniRate::ApiError(status_code: 403) and are covered in spec/client_spec.rb.

require "spec_helper"
require "unirate"

# Live tests hit the real API, so bypass WebMock for this file only.
WebMock.allow_net_connect!

RSpec.describe "UniRate::Client (live)", :live do
  before(:all) do
    skip "set UNIRATE_API_KEY to run live integration tests" unless ENV["UNIRATE_API_KEY"]
    @client = UniRate::Client.new(api_key: ENV["UNIRATE_API_KEY"])
  end

  it "fetches a current rate" do
    rate = @client.get_rate(from: "USD", to: "EUR")
    expect(rate).to be > 0
    expect(rate).to be < 10
  end

  it "fetches all rates for a base currency" do
    rates = @client.get_rate(from: "USD")
    expect(rates["EUR"]).not_to be_nil
    expect(rates.size).to be > 100
  end

  it "converts an amount" do
    result = @client.convert(amount: 100, from: "USD", to: "EUR")
    expect(result).to be > 0
    expect(result).to be < 1000
  end

  it "lists supported currencies" do
    currencies = @client.get_supported_currencies
    expect(currencies).to include("USD")
    expect(currencies).to include("EUR")
    expect(currencies.size).to be > 100
  end

  it "fetches VAT for a single country" do
    resp = @client.get_vat_rates(country: "DE")
    expect(resp["vat_data"]["country_code"]).to eq("DE")
    expect(resp["vat_data"]["country_name"]).to eq("Germany")
    expect(resp["vat_data"]["vat_rate"]).to eq(19.0)
  end

  it "fetches VAT for all countries" do
    resp = @client.get_vat_rates
    expect(resp["total_countries"]).to be > 20
    expect(resp["vat_rates"]["DE"]["country_name"]).to eq("Germany")
  end
end
