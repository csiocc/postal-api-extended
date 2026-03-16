# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Users#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:target_user) { create(:user) }
  let(:other_organization) { create(:organization) }
  let(:foreign_user) { create(:user) }

  before do
    organization.update!(owner: admin_user)
    target_user.organizations << organization
    foreign_user.organizations << other_organization
  end

  it "deletes users across organizations for admin credentials" do
    expect do
      delete "/api/v1/manage/users/#{foreign_user.uuid}",
             headers: management_api_headers(management_api_key)
    end.to change(User, :count).by(-1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "prevents self-deletion" do
    delete "/api/v1/manage/users/#{admin_user.uuid}",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end

  it "rejects revoked management API keys" do
    management_api_key.revoke!
    delete "/api/v1/manage/users/#{target_user.uuid}",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("ManagementAPIKeyRevoked")
  end

  it "returns error for non-existent user" do
    delete "/api/v1/manage/users/invalid-uuid",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end
end
