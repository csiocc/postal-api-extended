# frozen_string_literal: true

require "digest"

class ManagementAPIKey < ApplicationRecord

  include HasUUID

  attr_reader :key

  belongs_to :user

  validates :name, presence: true
  validates :key_digest, presence: true, uniqueness: true
  validate :user_must_be_admin_for_active_key

  before_validation :prepare_key_digest, on: :create

  scope :active, -> { where(revoked_at: nil) }

  class << self
    def authenticate(raw_key)
      digest = digest_for(raw_key)
      return nil if digest.blank?

      includes(:user).find_by(key_digest: digest)
    end

    def digest_for(raw_key)
      normalized_key = normalize_key(raw_key)
      return nil if normalized_key.blank?

      Digest::SHA256.hexdigest(normalized_key)
    end

    private

    def normalize_key(raw_key)
      raw_key.to_s.downcase
    end
  end

  def active?
    revoked_at.nil?
  end

  def revoked?
    !active?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  def use
    update_column(:last_used_at, Time.current)
  end

  def key=(value)
    @key = value.presence
  end

  private

  def generate_key
    return if key.present?

    self.key = SecureRandom.alphanumeric(40)
  end

  def prepare_key_digest
    generate_key
    self.key_digest = self.class.digest_for(key)
  end

  def user_must_be_admin_for_active_key
    return if revoked?
    return if user&.admin?

    errors.add(:user, "must be an admin user")
  end

end
