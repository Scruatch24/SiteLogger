# frozen_string_literal: true

require "openssl"
require "base64"

module Paddle
  class WebhookVerifier
    VERSION_PREFIX = "v1="

    def initialize(secret:)
      @secret = secret
    end

    def valid?(raw_body:, signature:)
      return false if @secret.blank? || signature.blank?

      signature = signature.to_s.strip

      if signature.include?("ts=") && signature.include?("h1=")
        ts, h1 = parse_ts_h1(signature)
        return false if ts.nil? || h1.nil?

        expected = compute_hmac_hex(ts: ts, payload: raw_body)
        return secure_compare(h1, expected)
      end

      # Fallback to older v1=base64 style if present
      return false unless signature.start_with?(VERSION_PREFIX)

      provided = signature.delete_prefix(VERSION_PREFIX)
      expected = compute_hmac_base64(payload: raw_body)
      secure_compare(provided, expected)
    end

    private

    def parse_ts_h1(signature)
      parts = signature.split(";").map { |p| p.split("=", 2) }.to_h
      [ parts["ts"], parts["h1"] ]
    end

    def compute_hmac_hex(ts:, payload:)
      digest = OpenSSL::Digest.new("sha256")
      OpenSSL::HMAC.hexdigest(digest, @secret, "#{ts}:#{payload}")
    end

    def compute_hmac_base64(payload:)
      digest = OpenSSL::Digest.new("sha256")
      raw = OpenSSL::HMAC.digest(digest, @secret, payload)
      Base64.strict_encode64(raw)
    end

    # Constant-time compare
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
