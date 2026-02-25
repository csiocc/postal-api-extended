# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:target_user) { create(:user, first_name: "Original") }
  let(:other_organization) { create(:organization) }
  let(:foreign_user) { create(:user, first_name: "Foreign") }

  before do
    organization.update!(owner: admin_user)
    target_user.organizations << organization
    foreign_user.organizations << other_organization
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "updates a user within the credential organization scope" do
    patch "/api/v1/users/#{target_user.uuid}",
          params: { first_name: "Updated" }.to_json,
          headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["first_name"]).to eq("Updated")

    target_user.reload
    expect(target_user.first_name).to eq("Updated")
  end

  it "blocks cross-organization updates for regular scoped credentials" do
    patch "/api/v1/users/#{foreign_user.uuid}",
          params: { first_name: "Blocked" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end

  it "allows cross-organization updates for global-admin credentials" do
    patch "/api/v1/users/#{foreign_user.uuid}",
          params: { first_name: "GlobalAdminUpdated" }.to_json,
          headers: json_headers_for(global_admin_credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "first_name")).to eq("GlobalAdminUpdated")

    foreign_user.reload
    expect(foreign_user.first_name).to eq("GlobalAdminUpdated")
  end

  it "prevents assigning out-of-scope organizations for regular credentials" do
    patch "/api/v1/users/#{target_user.uuid}",
          params: { organization_ids: [other_organization.id] }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")

    target_user.reload
    expect(target_user.organization_ids).to include(organization.id)
    expect(target_user.organization_ids).not_to include(other_organization.id)
  end

  it "prevents admin from removing own admin status" do
    patch "/api/v1/users/#{admin_user.uuid}",
          params: { admin: false }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end
end
