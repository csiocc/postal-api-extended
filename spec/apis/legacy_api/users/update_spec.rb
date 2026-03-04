# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Users#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

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

  it "updates users across organizations for admin credentials" do
    patch "/api/v1/users/#{foreign_user.uuid}",
          params: { first_name: "Updated" }.to_json,
          headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["first_name"]).to eq("Updated")

    foreign_user.reload
    expect(foreign_user.first_name).to eq("Updated")
  end

  it "allows assigning organizations across scopes for admin credentials" do
    patch "/api/v1/users/#{target_user.uuid}",
          params: { organization_ids: [organization.id, other_organization.id] }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    target_user.reload
    expect(target_user.organization_ids).to match_array([organization.id, other_organization.id])
  end

  it "denies access for non-admin organization owners" do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/users/#{target_user.uuid}",
          params: { first_name: "Blocked" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end

  it "prevents admin from removing own admin status" do
    patch "/api/v1/users/#{admin_user.uuid}",
          params: { admin: false }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end

  it "prevents admin from removing own admin status with string false" do
    patch "/api/v1/users/#{admin_user.uuid}",
          params: { admin: "false" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")

    admin_user.reload
    expect(admin_user.admin).to be(true)
  end
end
