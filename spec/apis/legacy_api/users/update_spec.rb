# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Users#update", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
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
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "updates users across organizations for admin credentials" do
    patch "/api/v1/manage/users/#{foreign_user.uuid}",
          params: { first_name: "Updated" }.to_json,
          headers: json_headers_for(management_api_key.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["first_name"]).to eq("Updated")

    foreign_user.reload
    expect(foreign_user.first_name).to eq("Updated")
  end

  it "allows assigning organizations across scopes for admin credentials" do
    patch "/api/v1/manage/users/#{target_user.uuid}",
          params: { organization_ids: [organization.id, other_organization.id] }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    target_user.reload
    expect(target_user.organization_ids).to match_array([organization.id, other_organization.id])
  end

  it "rejects revoked management API keys" do
    management_api_key.revoke!
    patch "/api/v1/manage/users/#{target_user.uuid}",
          params: { first_name: "Blocked" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("ManagementAPIKeyRevoked")
  end

  it "prevents admin from removing own admin status" do
    patch "/api/v1/manage/users/#{admin_user.uuid}",
          params: { admin: false }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end

  it "prevents admin from removing own admin status with string false" do
    patch "/api/v1/manage/users/#{admin_user.uuid}",
          params: { admin: "false" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")

    admin_user.reload
    expect(admin_user.admin).to be(true)
  end

  it "updates the password when provided" do
    patch "/api/v1/manage/users/#{target_user.uuid}",
          params: { password: "new-password-123", password_confirmation: "new-password-123" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    target_user.reload
    expect(target_user.authenticate("new-password-123")).to eq(target_user)
  end

  it "returns parameter-error for invalid updates" do
    patch "/api/v1/manage/users/#{target_user.uuid}",
          params: { email_address: "not-an-email" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
