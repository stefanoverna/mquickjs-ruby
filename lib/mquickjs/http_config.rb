# frozen_string_literal: true

require 'uri'
require 'ipaddr'
require 'net/http'

module MQuickJS
  class HTTPConfig
    DEFAULT_MAX_REQUESTS = 10
    DEFAULT_REQUEST_TIMEOUT = 5000  # ms
    DEFAULT_MAX_REQUEST_SIZE = 1_048_576  # 1MB
    DEFAULT_MAX_RESPONSE_SIZE = 1_048_576  # 1MB
    DEFAULT_ALLOWED_METHODS = %w[GET POST PUT DELETE PATCH HEAD].freeze
    DEFAULT_ALLOWED_PORTS = [80, 443].freeze

    # Private IP ranges (RFC 1918) and other blocked ranges
    BLOCKED_IP_RANGES = [
      '10.0.0.0/8',          # Private
      '172.16.0.0/12',       # Private
      '192.168.0.0/16',      # Private
      '127.0.0.0/8',         # Loopback
      '169.254.0.0/16',      # Link-local (AWS metadata)
      '::1/128',             # IPv6 loopback
      'fe80::/10',           # IPv6 link-local
      '169.254.169.254/32'   # AWS/GCP/Azure metadata
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    attr_reader :whitelist, :max_requests, :request_timeout,
                :max_request_size, :max_response_size, :allowed_methods,
                :block_private_ips, :allowed_ports

    def initialize(options = {})
      @whitelist = compile_patterns(options[:whitelist] || [])
      @max_requests = options[:max_requests] || DEFAULT_MAX_REQUESTS
      @request_timeout = options[:request_timeout] || DEFAULT_REQUEST_TIMEOUT
      @max_request_size = options[:max_request_size] || DEFAULT_MAX_REQUEST_SIZE
      @max_response_size = options[:max_response_size] || DEFAULT_MAX_RESPONSE_SIZE
      @allowed_methods = options[:allowed_methods] || DEFAULT_ALLOWED_METHODS
      @block_private_ips = options.fetch(:block_private_ips, true)
      @allowed_ports = options[:allowed_ports] || DEFAULT_ALLOWED_PORTS
    end

    # Check if a URL is allowed by the whitelist
    def allowed?(url)
      return false if @whitelist.empty?

      uri = URI.parse(url)

      # Check port if allowed_ports is specified
      port = uri.port || (uri.scheme == 'https' ? 443 : 80)
      return false if @allowed_ports && !@allowed_ports.include?(port)

      # Check against whitelist patterns
      @whitelist.any? { |pattern| pattern.match?(url) }
    rescue URI::InvalidURIError
      false
    end

    # Check if an IP address is blocked
    def blocked_ip?(ip_or_host)
      return false unless @block_private_ips

      # Resolve hostname to IP if needed
      ip_str = resolve_to_ip(ip_or_host)
      return false unless ip_str

      ip = IPAddr.new(ip_str)

      # Check against blocked ranges
      BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError, SocketError
      # If we can't parse/resolve, block it to be safe
      true
    end

    # Validate a URL before making a request
    def validate_url(url)
      uri = URI.parse(url)

      # Only allow http/https
      unless %w[http https].include?(uri.scheme)
        raise HTTPBlockedError, "URL scheme '#{uri.scheme}' not allowed"
      end

      # Check whitelist
      unless allowed?(url)
        raise HTTPBlockedError, "URL not in whitelist: #{url}"
      end

      # Check if host resolves to blocked IP
      if blocked_ip?(uri.host)
        raise HTTPBlockedError, "URL resolves to blocked IP address: #{url}"
      end

      true
    end

    # Validate HTTP method
    def validate_method(method)
      method_upper = method.to_s.upcase
      unless @allowed_methods.include?(method_upper)
        raise HTTPBlockedError, "HTTP method '#{method}' not allowed"
      end
      method_upper
    end

    private

    # Compile glob patterns to regex
    def compile_patterns(patterns)
      patterns.map do |pattern|
        # Convert glob pattern to regex
        # * matches anything except /
        # ** matches anything including /
        regex_str = Regexp.escape(pattern)
                          .gsub('\*\*', '___DOUBLE_STAR___')
                          .gsub('\*', '[^/]*')
                          .gsub('___DOUBLE_STAR___', '.*')

        Regexp.new("^#{regex_str}$")
      end
    end

    # Resolve hostname to IP address
    def resolve_to_ip(host)
      # If it's already an IP, return it
      begin
        IPAddr.new(host)
        return host
      rescue IPAddr::InvalidAddressError
        # Not an IP, continue to DNS resolution
      end

      # Resolve DNS
      begin
        require 'resolv'
        Resolv.getaddress(host)
      rescue Resolv::ResolvError
        nil
      end
    end
  end

  class HTTPRequest
    attr_reader :method, :url, :status, :duration_ms, :request_size, :response_size

    def initialize(method:, url:, status: nil, duration_ms: 0, request_size: 0, response_size: 0)
      @method = method
      @url = url
      @status = status
      @duration_ms = duration_ms
      @request_size = request_size
      @response_size = response_size
    end

    def to_h
      {
        method: @method,
        url: @url,
        status: @status,
        duration_ms: @duration_ms,
        request_size: @request_size,
        response_size: @response_size
      }
    end
  end
end
