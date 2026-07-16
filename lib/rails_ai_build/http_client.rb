# frozen_string_literal: true

require "net/http"
require "openssl"

module RailsAiBuild
  # Hardened outbound HTTP for providers, billing, webhooks, MCP.
  module HttpClient
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 60
    DEFAULT_WRITE_TIMEOUT = 30

    class << self
      def request(uri, request, open_timeout: nil, read_timeout: nil, write_timeout: nil)
        uri = Security::UrlGuard.safe_uri(uri)
        open_timeout ||= RailsAiBuild.configuration.http_open_timeout || DEFAULT_OPEN_TIMEOUT
        read_timeout ||= RailsAiBuild.configuration.http_read_timeout || DEFAULT_READ_TIMEOUT
        write_timeout ||= RailsAiBuild.configuration.http_write_timeout || DEFAULT_WRITE_TIMEOUT

        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          write_timeout: write_timeout,
          verify_mode: OpenSSL::SSL::VERIFY_PEER
        ) do |http|
          http.max_retries = 0
          response = http.request(request)
          raise ProviderError, "HTTP redirect not followed (#{response.code}) for #{uri.host}" if response.is_a?(Net::HTTPRedirection)

          response
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
        raise ProviderError, "HTTP timeout talking to #{uri.host}: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        raise ProviderError, "TLS error talking to #{uri.host}: #{e.message}"
      end
    end
  end
end
