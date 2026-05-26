# UniRate Ruby Client

Official Ruby client for the [UniRate API](https://unirateapi.com) — free, real-time and historical currency exchange rates plus VAT rates.

- Real-time exchange rates between 170+ currencies (fiat + crypto)
- Historical rates back to 1999
- Time-series ranges up to 5 years
- Currency conversion (current and historical)
- VAT rates for countries worldwide
- Free tier, no credit card required
- Pure stdlib: `net/http` + `json` — zero runtime dependencies

## Requirements

- Ruby 3.0+

## Installation

Add to your `Gemfile`:

```ruby
gem "unirate-api"
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install unirate-api
```

## Quick start

```ruby
require "unirate"

client = UniRate::Client.new(api_key: ENV.fetch("UNIRATE_API_KEY"))

# Current rate
rate = client.get_rate(from: "USD", to: "EUR")
puts "USD -> EUR: #{rate}"

# Convert
euros = client.convert(amount: 100, from: "USD", to: "EUR")
puts "100 USD = #{euros} EUR"

# All supported currencies
currencies = client.get_supported_currencies
puts "#{currencies.size} currencies supported"
```

Get a free API key at [https://unirateapi.com](https://unirateapi.com).

## API

All methods use keyword arguments. Currency and country codes are upcased automatically before the request is sent.

### Current rates

```ruby
# Single pair
rate = client.get_rate(from: "USD", to: "EUR")           # => Float

# All rates for a base
rates = client.get_rate(from: "USD")                     # => Hash{String=>Float}

# Convert an amount
result = client.convert(amount: 100, from: "USD", to: "EUR")  # => Float

# Supported currency list
codes = client.get_supported_currencies                  # => Array<String>
```

### Historical data

All historical methods require a Pro API key; they raise `UniRate::ApiError` (with `status_code: 403`) on the free tier.

```ruby
# Rate on a specific date
rate = client.get_historical_rate(date: "2024-01-01", from: "USD", to: "EUR")

# All rates on a date
rates = client.get_historical_rates(date: "2024-01-01", base: "USD")

# Convert using historical rate
amount = client.convert_historical(amount: 100, from: "USD", to: "EUR", date: "2024-01-01")

# Time series (up to 5 years)
series = client.get_time_series(
  start_date: "2024-01-01",
  end_date:   "2024-01-07",
  base:       "USD",
  currencies: ["EUR", "GBP"]
)

# Available historical coverage per currency
limits = client.get_historical_limits
```

### VAT rates

```ruby
# All countries
all = client.get_vat_rates

# Single country (ISO-3166 alpha-2)
germany = client.get_vat_rates(country: "DE")
puts germany["vat_data"]["vat_rate"]   # => 19.0
```

## Error handling

All methods raise subclasses of `UniRate::Error`:

```ruby
begin
  rate = client.get_rate(from: "USD", to: "ZZZ")
rescue UniRate::AuthenticationError
  # invalid API key (HTTP 401)
rescue UniRate::InvalidCurrencyError
  # unknown currency code (HTTP 404)
rescue UniRate::RateLimitError
  # back off and retry (HTTP 429)
rescue UniRate::InvalidDateError
  # bad date format or bad request (HTTP 400)
rescue UniRate::ApiError => e
  # other HTTP error — e.status_code, e.response
end
```

| Status | Error class |
|--------|-------------|
| 400 | `UniRate::InvalidDateError` |
| 401 | `UniRate::AuthenticationError` |
| 403 | `UniRate::ApiError` (status 403 — Pro-only endpoint) |
| 404 | `UniRate::InvalidCurrencyError` |
| 429 | `UniRate::RateLimitError` |
| 503 | `UniRate::ApiError` (status 503) |
| other | `UniRate::ApiError` |
| network | `UniRate::Error` (base) |

## Testing

The client uses `Net::HTTP` directly, so [WebMock](https://github.com/bblimke/webmock) stubs requests transparently in tests:

```ruby
require "webmock/rspec"
require "unirate"

stub_request(:get, "https://api.unirateapi.com/api/rates")
  .with(query: hash_including("from" => "USD", "to" => "EUR"))
  .to_return(status: 200, body: { rate: "0.9321" }.to_json)

client = UniRate::Client.new(api_key: "test")
rate = client.get_rate(from: "USD", to: "EUR")   # => 0.9321
```

Run the suites in this repo:

```bash
bundle exec rspec spec/client_spec.rb             # ~14 WebMock-based mock tests
UNIRATE_API_KEY=your-key bundle exec rspec spec/live_spec.rb   # live (free-tier only)
```

## Rate limits

- **Currency endpoints:** standard rate limits apply
- **Historical endpoints:** 50 requests/hour on the free tier
- **VAT endpoints:** 1800 requests/hour on the free tier

## Related clients

- [unirate-api-python](https://github.com/UniRate-API/unirate-api-python) (PyPI: `unirate-api`)
- [unirate-api-nodejs](https://github.com/UniRate-API/unirate-api-nodejs) (npm: `unirate-api`)
- [unirate-api-swift](https://github.com/UniRate-API/unirate-api-swift) (Swift Package Manager)

<!-- unirate-ecosystem-footer:start -->
## Other UniRate clients

UniRate ships official client libraries and framework integrations across the
ecosystem. The repos below are all maintained under the
[UniRate-API](https://github.com/UniRate-API) org.

- **Languages:** [Python](https://github.com/UniRate-API/unirate-api-python) · [Node.js / TypeScript](https://github.com/UniRate-API/unirate-api-nodejs) · [Go](https://github.com/UniRate-API/unirate-api-go) · [Rust](https://github.com/UniRate-API/unirate-api-rust) · [Java](https://github.com/UniRate-API/unirate-api-java) · [Ruby](https://github.com/UniRate-API/unirate-api-ruby) · [PHP](https://github.com/UniRate-API/unirate-api-php) · [.NET](https://github.com/UniRate-API/unirate-api-dotnet) · [Swift](https://github.com/UniRate-API/unirate-api-swift)
- **Web frameworks:** [NestJS](https://github.com/UniRate-API/nestjs-unirate) · [Django / Wagtail](https://github.com/UniRate-API/wagtail-unirate) · [FastAPI](https://github.com/UniRate-API/fastapi-unirate) · [Flask](https://github.com/UniRate-API/flask-unirate) · [React](https://github.com/UniRate-API/react-unirate) · [tRPC](https://github.com/UniRate-API/trpc-unirate)
- **Static-site generators:** [Astro](https://github.com/UniRate-API/astro-unirate) · [Eleventy](https://github.com/UniRate-API/eleventy-unirate) · [Hugo](https://github.com/UniRate-API/hugo-unirate)
- **Data / orchestration:** [Airflow](https://github.com/UniRate-API/airflow-provider-unirate) · [dbt](https://github.com/UniRate-API/dbt-unirate) · [LangChain](https://github.com/UniRate-API/langchain-unirate)
- **Workflow / no-code:** [n8n](https://github.com/UniRate-API/n8n-nodes-unirate) · [Google Sheets](https://github.com/UniRate-API/unirate-sheets) · [MCP server](https://github.com/UniRate-API/unirate-mcp)
- **Editors / tools:** [VS Code](https://github.com/UniRate-API/vscode-unirate) · [Obsidian](https://github.com/UniRate-API/obsidian-currency)
- **Specialty bridges:** [NodaMoney (.NET)](https://github.com/UniRate-API/UniRateApi.NodaMoney)

Get a free API key at [unirateapi.com](https://unirateapi.com).
<!-- unirate-ecosystem-footer:end -->

## License

MIT — see [LICENSE](LICENSE).
