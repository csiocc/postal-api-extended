# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#create", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let!(:server) { create(:server, organization: organization) }
  let(:other_organization) { create(:organization) }
  let!(:other_server) { create(:server, organization: other_organization) }

  let(:valid_params) do
    {
      type: "API",
      name: "API Credential",
      server_id: server.id
    }
  end

  def json_headers_for(api_key)
    {
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "allows creating a credential on any server for management API keys" do
    expect do
      post "/api/v1/manage/credentials",
           params: valid_params.merge(server_id: other_server.id).to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Credential, :count).by(1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "creates credentials on the provided server" do
    post "/api/v1/manage/credentials",
         params: valid_params.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.server_id).to eq(server.id)
  end

  it "requires server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.except(:server_id).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id is required")
  end

  it "accepts numeric hold values" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(name: "Held Credential", hold: 1).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "hold")).to eq(true)
  end

  it "returns parameter-error for invalid server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(server_id: "abc").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id must be an integer")
  end

  it "returns ServerNotFound for unknown server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(server_id: 9_999_999).to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "defaults type to SMTP when no type is provided" do
    post "/api/v1/manage/credentials",
         params: { name: "Default SMTP Credential", server_id: server.id }.to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.type).to eq("SMTP")
  end

  it "returns parameter-error for invalid type" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(type: "BROKEN").to_json,
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/credentials",
         params: '{"name":"broken-json"',
         headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end
end
