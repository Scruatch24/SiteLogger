require "zlib"

class UsageEvent < ApplicationRecord
  belongs_to :user, optional: true

  PADDLE_WEBHOOK_EVENT = "paddle_webhook".freeze

  def self.process_paddle_webhook_once!(external_id:, payload_hash:, ip_address: nil)
    result = :processed

    transaction do
      with_advisory_lock("paddle_webhook:#{external_id}") do
        receipt = find_by(event_type: PADDLE_WEBHOOK_EVENT, session_id: external_id)

        if receipt
          Rails.logger.warn("Paddle webhook duplicate payload mismatch for #{external_id}") if receipt.data_hash.present? && receipt.data_hash != payload_hash
          result = :duplicate
        else
          yield
          create!(
            event_type: PADDLE_WEBHOOK_EVENT,
            session_id: external_id,
            ip_address: ip_address,
            data_hash: payload_hash
          )
        end
      end

      raise ActiveRecord::Rollback if result == :duplicate
    end

    result
  end

  def self.with_advisory_lock(key)
    lock_key = Zlib.crc32(key.to_s)
    sql = sanitize_sql_array(["SELECT pg_advisory_xact_lock(?)", lock_key])
    connection.execute(sql)
    yield
  end
  private_class_method :with_advisory_lock
end
