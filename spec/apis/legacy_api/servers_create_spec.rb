# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#create", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }
  let(:admin_user) { create(:user, :admin) }
  let!(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      name: "API Server",
      permalink: "api-server",
      mode: "Live",
      organization_id: organization.id
    }
  end

  def json_headers_for(api_key)
    {
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "allows creating a server in any organization for management API keys" do
    expect do
      post "/api/v1/manage/servers",
           params: valid_params.merge(
             name: "Cross Org Server",
             permalink: "cross-org-server",
             organization_id: other_organization.id
           ).to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Server, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "creates a server in the provided organization" do
    post "/api/v1/manage/servers",
         params: valid_params.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_server = Server.find_by!(uuid: json.dig("data", "server", "uuid"))
    expect(created_server.organization_id).to eq(organization.id)
  end

  it "requires organization_id" do
    post "/api/v1/manage/servers",
         params: valid_params.except(:organization_id).merge(permalink: "default-org-server").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id is required")
  end

  it "returns parameter-error for invalid organization_id" do
    post "/api/v1/manage/servers",
         params: valid_params.merge(organization_id: "abc").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id must be an integer")
  end

  it "returns OrganizationNotFound for unknown organization_id" do
    post "/api/v1/manage/servers",
         params: valid_params.merge(organization_id: 9_999_999).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("OrganizationNotFound")
  end

  it "returns parameter-error for invalid mode" do
    invalid_params = valid_params.merge(mode: "BrokenMode")

    post "/api/v1/manage/servers",
         params: invalid_params.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/servers",
         params: '{"name":"broken-json"',
         headers: json_headers_for(management_api_key.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end

  it "rejects revoked management API keys" do
    management_api_key.revoke!
    post "/api/v1/manage/servers",
         params: valid_params.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ManagementAPIKeyRevoked")
  end
end
