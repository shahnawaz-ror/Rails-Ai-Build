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

      # Carrier-grade NAT / shared address space — treat like private.
      CGNAT = IPAddr.new("100.64.0.0/10")
      IPV4_MAPPED_PREFIX = IPAddr.new("::ffff:0:0/96")

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

          # Allowlist is an extra permit list, not a bypass of IP safety checks.
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
          return [normalize_ip(IPAddr.new(host))] if ip_literal?(host)

          Resolv.getaddresses(host).map { |addr| normalize_ip(IPAddr.new(addr)) }
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

          assert_ip_allowed!(normalize_ip(IPAddr.new(host)), host)
        end

        def assert_ip_allowed!(ip, host)
          ip = normalize_ip(ip)

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

          # Explicit allowlist can permit otherwise-public hosts only (already passed IP checks).
          true
        end

        # Collapse IPv4-mapped IPv6 (::ffff:x.x.x.x) to IPv4 for policy checks.
        def normalize_ip(ip)
          return ip unless ip.ipv6?

          str = ip.to_s.downcase
          if (match = str.match(/\A::ffff:(\d+\.\d+\.\d+\.\d+)\z/))
            return IPAddr.new(match[1])
          end

          return ip unless IPV4_MAPPED_PREFIX.include?(ip)
          return IPAddr.new(ip.native.to_s) if ip.respond_to?(:native)

          ip
        rescue StandardError
          ip
        end

        def loopback?(ip)
          ip = normalize_ip(ip)
          ip.loopback? || ip.to_s == "::1" || ip.to_s == "127.0.0.1"
        end

        def private_ip?(ip)
          ip = normalize_ip(ip)
          ip.private? || CGNAT.include?(ip)
        end

        def link_local_or_metadata?(ip)
          ip = normalize_ip(ip)
          # 169.254.0.0/16 and IPv6 fe80::/10
          ip.link_local? || IPAddr.new("169.254.0.0/16").include?(ip)
        rescue StandardError
          false
        end
      end
    end
  end
end
