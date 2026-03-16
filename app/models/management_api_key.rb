# frozen_string_literal: true

class ManagementAPIKey < ApplicationRecord

  include HasUUID

  belongs_to :user

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validate :user_must_be_admin_for_active_key

  before_validation :generate_key, on: :create

  scope :active, -> { where(revoked_at: nil) }

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

  private

  def generate_key
    return if key.present?

    self.key = SecureRandom.alphanumeric(40)
  end

  def user_must_be_admin_for_active_key
    return if revoked?
    return if user&.admin?

    errors.add(:user, "must be an admin user")
  end

end
