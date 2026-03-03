# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Credentials#create", type: :request do
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
  let!(:other_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      type: "API",
      name: "API Credential"
    }
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "creates a credential on the current server when server_id is omitted" do
    expect do
      post "/api/v1/credentials",
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(Credential, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "name")).to eq("API Credential")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.server_id).to eq(server.id)
  end

  it "denies creating credentials on servers outside credential scope" do
    out_of_scope_params = valid_params.merge(server_id: other_server.id)

    expect do
      post "/api/v1/credentials",
           params: out_of_scope_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Credential, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "allows cross-organization creation for global-admin credentials" do
    cross_org_params = valid_params.merge(server_id: other_server.id, name: "Global Credential")

    post "/api/v1/credentials",
         params: cross_org_params.to_json,
         headers: json_headers_for(global_admin_credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.server_id).to eq(other_server.id)
  end

  it "defaults type to SMTP when no type is provided" do
    params_without_type = { name: "Default SMTP Credential" }

    post "/api/v1/credentials",
         params: params_without_type.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.type).to eq("SMTP")
  end

  it "returns parameter-error for invalid type" do
    invalid_params = valid_params.merge(type: "BROKEN")

    post "/api/v1/credentials",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/credentials",
         params: '{"name":"broken-json"',
         headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end
end
