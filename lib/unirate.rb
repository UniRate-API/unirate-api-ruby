# frozen_string_literal: true

require_relative "unirate/version"
require_relative "unirate/errors"
require_relative "unirate/client"

# Top-level namespace for the UniRate Ruby client.
#
#   client = UniRate::Client.new(api_key: ENV.fetch("UNIRATE_API_KEY"))
#   rate   = client.get_rate(from: "USD", to: "EUR")
module UniRate
end
