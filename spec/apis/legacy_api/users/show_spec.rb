# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Users#show", type: :request do
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

  it "returns user details for users inside the credential scope" do
    get "/api/v1/manage/users/#{target_user.uuid}",
        headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "uuid")).to eq(target_user.uuid)
  end

  it "allows cross-organization user reads for admin credentials" do
    get "/api/v1/manage/users/#{foreign_user.uuid}",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "uuid")).to eq(foreign_user.uuid)
  end

  it "returns not found for unknown users" do
    get "/api/v1/manage/users/invalid-uuid",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end
end
