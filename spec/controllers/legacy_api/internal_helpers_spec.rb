# frozen_string_literal: true

require "rails_helper"

RSpec.describe ManagementAPI::CredentialsController, type: :controller do
  describe "#current_organization" do
    it "returns the credential organization helper value" do
      organization = build_stubbed(:organization)
      allow(controller).to receive(:current_api_organization).and_return(organization)

      expect(controller.send(:current_organization)).to eq(organization)
    end
  end
end

RSpec.describe ManagementAPI::UsersController, type: :controller do
  describe "#scoped_users" do
    it "returns users from visible organizations for non-admin contexts" do
      current_user = create(:user, admin: false)
      organization = create(:organization, owner: create(:user))
      member_user = create(:user)
      outsider = create(:user)
      member_user.organizations << organization

      allow(controller).to receive(:current_api_user).and_return(current_user)
      allow(controller).to receive(:scoped_organizations_for_current_api_user).and_return(Organization.where(id: organization.id))

      result = controller.send(:scoped_users)

      expect(result).to include(organization.owner, member_user)
      expect(result).not_to include(outsider)
    end
  end

  describe "#authorized_organization_ids" do
    let(:current_user) { create(:user, admin: false) }
    let!(:allowed_organization) { create(:organization) }
    let!(:forbidden_organization) { create(:organization) }

    before do
      allow(controller).to receive(:current_api_user).and_return(current_user)
      allow(controller).to receive(:scoped_organizations_for_current_api_user).and_return(
        Organization.where(id: allowed_organization.id)
      )
    end

    it "returns allowed organization ids for non-admin contexts" do
      result = controller.send(:authorized_organization_ids, [allowed_organization.id])

      expect(result).to eq([allowed_organization.id])
    end

    it "rejects organizations outside scope for non-admin contexts" do
      expect(controller).to receive(:render_error).with(
        "AccessDenied",
        message: "organization_ids contains organizations outside your scope",
        organization_ids: [forbidden_organization.id]
      )

      result = controller.send(:authorized_organization_ids, [allowed_organization.id, forbidden_organization.id])

      expect(result).to be_nil
    end
  end
end
