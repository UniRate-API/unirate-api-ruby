# frozen_string_literal: true

# Basic usage example for the UniRate Ruby client.
#
# Run with:
#
#   UNIRATE_API_KEY=your-key ruby examples/basic.rb

require "unirate"

api_key = ENV.fetch("UNIRATE_API_KEY", nil)
if api_key.nil? || api_key.empty?
  warn "Set UNIRATE_API_KEY in the environment. Get a free key at https://unirateapi.com."
  exit 1
end

client = UniRate::Client.new(api_key: api_key)

# 1. Current rate
rate = client.get_rate(from: "USD", to: "EUR")
puts "USD -> EUR: #{rate}"

# 2. Convert an amount
result = client.convert(amount: 100, from: "USD", to: "EUR")
puts "100 USD = #{result} EUR"

# 3. List supported currencies
currencies = client.get_supported_currencies
puts "#{currencies.size} currencies supported (first 5: #{currencies.first(5).join(', ')})"
