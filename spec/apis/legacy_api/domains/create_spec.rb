# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#create", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let!(:other_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      name: "mail-api.example",
      verification_method: "DNS"
    }
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "creates a server-owned domain on current server when no target is provided" do
    expect do
      post "/api/v1/manage/domains",
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(Domain, :count).by(1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_domain = Domain.find_by!(uuid: json.dig("data", "domain", "uuid"))
    expect(created_domain.owner).to eq(server)
    expect(created_domain.name).to eq("mail-api.example")
  end

  it "creates an organization-owned domain when organization_id is provided" do
    params = valid_params.merge(name: "org-owned.example", organization_id: organization.id)

    post "/api/v1/manage/domains",
         params: params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_domain = Domain.find_by!(uuid: json.dig("data", "domain", "uuid"))
    expect(created_domain.owner).to eq(organization)
  end

  it "creates an organization-owned domain for the current organization when scope=organization" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(name: "scoped-org.example", scope: "organization").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_domain = Domain.find_by!(uuid: json.dig("data", "domain", "uuid"))
    expect(created_domain.owner).to eq(organization)
  end

  it "denies cross-organization creation for admin credentials" do
    params = valid_params.merge(name: "cross-org.example", server_id: other_server.id)

    expect do
      post "/api/v1/manage/domains",
           params: params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Domain, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "returns parameter-error when scope=server is combined with organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "server", organization_id: organization.id).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id cannot be used when scope=server")
  end

  it "returns parameter-error when scope=organization is combined with server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "organization", server_id: server.id).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id cannot be used when scope=organization")
  end

  it "denies creating domains on servers outside credential scope for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))
    params = valid_params.merge(server_id: other_server.id)

    expect do
      post "/api/v1/manage/domains",
           params: params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Domain, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "returns parameter-error for invalid server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(server_id: "abc").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id must be an integer")
  end

  it "returns ServerNotFound for unknown server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(server_id: 9_999_999).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "returns parameter-error for invalid organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(organization_id: "abc").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id must be an integer")
  end

  it "returns OrganizationNotFound for unknown organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(organization_id: 9_999_999).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("OrganizationNotFound")
  end

  it "denies creating domains in assigned organizations outside the credential organization" do
    non_admin_user = create(:user, admin: false)
    organization.update!(owner: non_admin_user)
    OrganizationUser.create!(organization: other_organization, user: non_admin_user, admin: false, all_servers: true)

    params = valid_params.merge(name: "assigned-org.example", organization_id: other_organization.id)

    expect do
      post "/api/v1/manage/domains",
           params: params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Domain, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "returns parameter-error when server_id and organization_id are both provided" do
    params = valid_params.merge(server_id: server.id, organization_id: organization.id)

    post "/api/v1/manage/domains",
         params: params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error when scope is invalid" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "team").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error when domain already exists for the same owner" do
    create(:domain, owner: server, name: "duplicate.example")

    post "/api/v1/manage/domains",
         params: valid_params.merge(name: "duplicate.example").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to include("already")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/domains",
         params: '{"name":"broken-json"',
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end

  it "returns AccessDenied when the credential has no user context" do
    organization.update_column(:owner_id, nil)

    post "/api/v1/manage/domains",
         params: valid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
