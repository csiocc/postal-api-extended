# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#create", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
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
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "creates a server in credential organization scope" do
    expect do
      post "/api/v1/servers",
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(Server, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "permalink")).to eq("api-server")

    created_server = Server.find_by!(uuid: json.dig("data", "server", "uuid"))
    expect(created_server.organization_id).to eq(organization.id)
  end

  it "denies creating a server outside credential scope" do
    out_of_scope_params = valid_params.merge(
      name: "Other Org Server",
      permalink: "other-org-server",
      organization_id: other_organization.id
    )

    expect do
      post "/api/v1/servers",
           params: out_of_scope_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Server, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "allows cross-organization creation for global-admin credentials" do
    cross_org_params = valid_params.merge(
      name: "Global Admin Server",
      permalink: "global-admin-server",
      organization_id: other_organization.id
    )

    post "/api/v1/servers",
         params: cross_org_params.to_json,
         headers: json_headers_for(global_admin_credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_server = Server.find_by!(uuid: json.dig("data", "server", "uuid"))
    expect(created_server.organization_id).to eq(other_organization.id)
  end

  it "returns parameter-error for invalid mode" do
    invalid_params = valid_params.merge(mode: "BrokenMode")

    post "/api/v1/servers",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/servers",
         params: '{"name":"broken-json"',
         headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end
end
