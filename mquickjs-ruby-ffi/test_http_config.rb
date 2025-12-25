#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/mquickjs'
require 'minitest/autorun'

class TestHTTPConfig < Minitest::Test
  def test_whitelist_exact_match
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://api.github.com/users/octocat']
    )

    assert config.allowed?('https://api.github.com/users/octocat')
    refute config.allowed?('https://api.github.com/users/other')
  end

  def test_whitelist_wildcard_path
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://api.github.com/users/*']
    )

    assert config.allowed?('https://api.github.com/users/octocat')
    assert config.allowed?('https://api.github.com/users/anyone')
    refute config.allowed?('https://api.github.com/repos/foo')
  end

  def test_whitelist_double_wildcard
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://api.github.com/**']
    )

    assert config.allowed?('https://api.github.com/users/octocat')
    assert config.allowed?('https://api.github.com/repos/foo/bar')
    refute config.allowed?('https://other.com/anything')
  end

  def test_port_validation
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://api.example.com/**'],
      allowed_ports: [443]
    )

    assert config.allowed?('https://api.example.com/data')
    refute config.allowed?('https://api.example.com:8080/data')
  end

  def test_blocked_private_ips
    config = MQuickJS::HTTPConfig.new(block_private_ips: true)

    assert config.blocked_ip?('127.0.0.1')
    assert config.blocked_ip?('10.0.0.1')
    assert config.blocked_ip?('192.168.1.1')
    assert config.blocked_ip?('172.16.0.1')
    assert config.blocked_ip?('169.254.169.254')

    refute config.blocked_ip?('8.8.8.8')
    refute config.blocked_ip?('1.1.1.1')
  end

  def test_allowed_private_ips_when_disabled
    config = MQuickJS::HTTPConfig.new(block_private_ips: false)

    refute config.blocked_ip?('127.0.0.1')
    refute config.blocked_ip?('10.0.0.1')
  end

  def test_validate_url_not_in_whitelist
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://allowed.com/**']
    )

    error = assert_raises(MQuickJS::HTTPBlockedError) do
      config.validate_url('https://evil.com/data')
    end
    assert_match(/not in whitelist/, error.message)
  end

  def test_validate_url_blocked_ip
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['http://localhost/**'],
      block_private_ips: true
    )

    # localhost resolves to 127.0.0.1 which is blocked
    error = assert_raises(MQuickJS::HTTPBlockedError) do
      config.validate_url('http://localhost/admin')
    end
    assert_match(/blocked IP/, error.message)
  end

  def test_validate_method
    config = MQuickJS::HTTPConfig.new

    assert_equal 'GET', config.validate_method('get')
    assert_equal 'POST', config.validate_method('post')
    assert_equal 'PUT', config.validate_method('PUT')

    error = assert_raises(MQuickJS::HTTPBlockedError) do
      config.validate_method('TRACE')
    end
    assert_match(/not allowed/, error.message)
  end

  def test_default_configuration
    config = MQuickJS::HTTPConfig.new

    assert_equal 10, config.max_requests
    assert_equal 2, config.max_concurrent
    assert_equal 5000, config.request_timeout
    assert_equal 1_048_576, config.max_request_size
    assert_equal 1_048_576, config.max_response_size
    assert_equal false, config.follow_redirects
    assert_equal [80, 443], config.allowed_ports
  end

  def test_custom_configuration
    config = MQuickJS::HTTPConfig.new(
      max_requests: 5,
      request_timeout: 1000,
      allowed_ports: [443]
    )

    assert_equal 5, config.max_requests
    assert_equal 1000, config.request_timeout
    assert_equal [443], config.allowed_ports
  end

  def test_empty_whitelist_blocks_all
    config = MQuickJS::HTTPConfig.new(whitelist: [])

    refute config.allowed?('https://any.com/path')
  end

  def test_subdomain_wildcard
    config = MQuickJS::HTTPConfig.new(
      whitelist: ['https://*.example.com/api/*']
    )

    assert config.allowed?('https://api.example.com/api/users')
    assert config.allowed?('https://beta.example.com/api/data')
    refute config.allowed?('https://example.com/api/users')  # No subdomain
    refute config.allowed?('https://api.example.com/other')  # Wrong path
  end
end

puts "Running HTTP configuration tests..."
