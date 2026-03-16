# frozen_string_literal: true

require "rails_helper"

describe ManagementAPIKey do
  subject(:management_api_key) { build(:management_api_key, key: "A" * 40) }

  describe "relationships" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "requires an admin user for active keys" do
      management_api_key.user = build(:user, admin: false)

      expect(management_api_key).not_to be_valid
      expect(management_api_key.errors[:user]).to include("must be an admin user")
    end

    it "allows revoked keys to remain attached to non-admin users" do
      management_api_key.user = build(:user, admin: false)
      management_api_key.revoked_at = Time.current

      expect(management_api_key).to be_valid
    end

    it "rejects duplicate keys case-insensitively" do
      create(:management_api_key, key: "dupKEY1234567890dupKEY1234567890dupKEY12")
      duplicate = build(:management_api_key, key: "dupkey1234567890dupkey1234567890dupkey12")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end
  end

  describe "creation" do
    it "generates a key when one is not provided" do
      management_api_key.key = nil

      expect { management_api_key.save! }.to change(management_api_key, :key).from(nil).to(match(/\A[a-zA-Z0-9]{40}\z/))
    end

    it "generates a UUID" do
      expect { management_api_key.save! }.to change(management_api_key, :uuid).from(nil).to(match(/[a-f0-9-]{36}/))
    end

    it "keeps an explicitly provided key" do
      expect { management_api_key.save! }.not_to change(management_api_key, :key)
    end
  end

  describe "#revoke!" do
    it "marks the key as revoked" do
      management_api_key.save!

      expect { management_api_key.revoke! }.to change(management_api_key, :revoked_at).from(nil).to(be_present)
      expect(management_api_key).to be_revoked
    end
  end

  describe "#use" do
    it "updates last_used_at" do
      management_api_key.save!

      expect { management_api_key.use }.to change(management_api_key, :last_used_at).from(nil).to(be_present)
    end
  end
end
