# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#create", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:cockpit_credential) do
    create(:credential,
           server: server,
           options: { "allow_cross_organization_user_management" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      email_address: "newuser@test.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      password_confirmation: "password123",
      organization_ids: [organization.id]
    }
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "creates a new user with organization_ids in scope" do
    expect do
      post "/api/v1/users",
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(User, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["email_address"]).to eq("newuser@test.com")
    expect(json["data"]["user"]["organizations"].map { |org| org["uuid"] })
      .to contain_exactly(organization.uuid)
  end

  it "denies assigning users to organizations outside the credential scope" do
    out_of_scope_params = valid_params.merge(organization_ids: [other_organization.id])

    expect do
      post "/api/v1/users",
           params: out_of_scope_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(User, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end

  it "allows cross-organization assignment for cockpit-scoped credentials" do
    cross_org_params = valid_params.merge(
      email_address: "cockpit-user@test.com",
      organization_ids: [organization.id, other_organization.id]
    )

    post "/api/v1/users",
         params: cross_org_params.to_json,
         headers: json_headers_for(cockpit_credential.key)

    json = JSON.parse(response.body)
    created_user = User.find_by!(uuid: json.dig("data", "user", "uuid"))

    expect(json["status"]).to eq("success")
    expect(created_user.organization_ids).to match_array([organization.id, other_organization.id])
  end

  it "returns error for invalid email" do
    invalid_params = valid_params.merge(email_address: "invalid-email")

    post "/api/v1/users",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns error for password mismatch" do
    invalid_params = valid_params.merge(password_confirmation: "different")

    post "/api/v1/users",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
