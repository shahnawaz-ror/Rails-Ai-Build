# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "uri"

module RailsAiBuild
  module Security
    # SSRF controls for outbound provider / webhook / MCP HTTP calls (SEC-07).
    class UrlGuard
      BLOCKED_METADATA_HOSTS = %w[
        metadata
        metadata.google.internal
        metadata.goog
        169.254.169.254
      ].freeze

      class << self
        def validate!(url)
          return true unless enabled?

          uri = parse!(url)
          assert_scheme!(uri)
          assert_host!(uri)
          assert_not_metadata!(uri)
          assert_resolved_safe!(uri)
          true
        end

        def safe_uri(url)
          validate!(url)
          URI(url.to_s)
        end

        def enabled?
          RailsAiBuild.configuration.ssrf_protection != false
        end

        private

        def parse!(url)
          raise ConfigurationError, "URL blank" if url.to_s.strip.empty?

          URI.parse(url.to_s)
        rescue URI::InvalidURIError => e
          raise ConfigurationError, "Invalid URL: #{e.message}"
        end

        def assert_scheme!(uri)
          scheme = uri.scheme.to_s.downcase
          return if %w[http https].include?(scheme)

          raise ConfigurationError, "URL scheme not allowed: #{scheme.inspect} (http/https only)"
        end

        def assert_host!(uri)
          host = uri.hostname.to_s.downcase
          raise ConfigurationError, "URL missing host" if host.empty?

          allowlist = Array(RailsAiBuild.configuration.ssrf_allowed_hosts).map { |h| h.to_s.downcase }
          return if allowlist.include?(host)

          true
        end

        def assert_not_metadata!(uri)
          host = uri.hostname.to_s.downcase
          return unless BLOCKED_METADATA_HOSTS.include?(host) || host.end_with?(".metadata.google.internal")

          raise ConfigurationError, "Blocked metadata host: #{host}"
        end

        def assert_resolved_safe!(uri)
          host = uri.hostname.to_s
          ips = resolve_ips(host)
          if ips.empty?
            # Hostname may be unresolved offline; still block obvious IP literals
            check_ip_literal!(host)
            return
          end

          ips.each { |ip| assert_ip_allowed!(ip, host) }
        end

        def resolve_ips(host)
          return [IPAddr.new(host)] if ip_literal?(host)

          Resolv.getaddresses(host).map { |addr| IPAddr.new(addr) }
        rescue Resolv::ResolvError, IPAddr::InvalidAddressError
          []
        end

        def ip_literal?(host)
          IPAddr.new(host)
          true
        rescue IPAddr::InvalidAddressError
          false
        end

        def check_ip_literal!(host)
          return unless ip_literal?(host)

          assert_ip_allowed!(IPAddr.new(host), host)
        end

        def assert_ip_allowed!(ip, host)
          if link_local_or_metadata?(ip)
            raise ConfigurationError, "Blocked link-local/metadata IP for #{host}: #{ip}"
          end

          if loopback?(ip)
            return if RailsAiBuild.configuration.ssrf_allow_localhost != false

            raise ConfigurationError, "Localhost URLs blocked (set config.ssrf_allow_localhost = true for Ollama)"
          end

          if private_ip?(ip)
            return if RailsAiBuild.configuration.ssrf_allow_private == true

            raise ConfigurationError,
                  "Private network URL blocked for #{host}: #{ip} (set config.ssrf_allow_private = true if intentional)"
          end

          true
        end

        def loopback?(ip)
          ip.loopback? || ip.to_s == "::1"
        end

        def private_ip?(ip)
          ip.private?
        end

        def link_local_or_metadata?(ip)
          # 169.254.0.0/16 and IPv6 fe80::/10
          ip.link_local? || IPAddr.new("169.254.0.0/16").include?(ip)
        rescue StandardError
          false
        end
      end
    end
  end
end
