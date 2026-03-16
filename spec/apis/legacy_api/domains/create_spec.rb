# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#create", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let!(:server) { create(:server, organization: organization) }
  let(:other_organization) { create(:organization) }
  let!(:other_server) { create(:server, organization: other_organization) }

  let(:valid_params) do
    {
      name: "mail-api.example"
    }
  end

  def json_headers_for(api_key)
    {
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "creates a server-owned domain when server_id is provided" do
    expect do
      post "/api/v1/manage/domains",
           params: valid_params.merge(server_id: server.id).to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Domain, :count).by(1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_domain = Domain.find_by!(uuid: json.dig("data", "domain", "uuid"))
    expect(created_domain.owner).to eq(server)
  end

  it "creates an organization-owned domain when organization_id is provided" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(name: "org-owned.example", organization_id: organization.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_domain = Domain.find_by!(uuid: json.dig("data", "domain", "uuid"))
    expect(created_domain.owner).to eq(organization)
  end

  it "allows targeting foreign organizations and servers with management API keys" do
    expect do
      post "/api/v1/manage/domains",
           params: valid_params.merge(name: "cross-org.example", server_id: other_server.id).to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Domain, :count).by(1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "requires a target owner" do
    post "/api/v1/manage/domains",
         params: valid_params.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id or organization_id must be provided")
  end

  it "returns parameter-error when scope=server is combined with organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "server", organization_id: organization.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id cannot be used when scope=server")
  end

  it "returns parameter-error when scope=organization is combined with server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "organization", server_id: server.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id cannot be used when scope=organization")
  end

  it "returns parameter-error for invalid server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(server_id: "abc").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id must be an integer")
  end

  it "returns ServerNotFound for unknown server_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(server_id: 9_999_999).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "returns parameter-error for invalid organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(organization_id: "abc").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id must be an integer")
  end

  it "returns OrganizationNotFound for unknown organization_id" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(organization_id: 9_999_999).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("OrganizationNotFound")
  end

  it "returns parameter-error when server_id and organization_id are both provided" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(server_id: server.id, organization_id: organization.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error when scope is invalid" do
    post "/api/v1/manage/domains",
         params: valid_params.merge(scope: "team", server_id: server.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error when domain already exists for the same owner" do
    create(:domain, owner: server, name: "duplicate.example")

    post "/api/v1/manage/domains",
         params: valid_params.merge(name: "duplicate.example", server_id: server.id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to include("already")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/domains",
         params: '{"name":"broken-json"',
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end
end
