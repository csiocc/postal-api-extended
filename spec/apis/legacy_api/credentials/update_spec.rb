# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#update", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
  let(:target_credential) { create(:credential, server: server, name: "Original Credential", hold: false) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }
  let(:foreign_credential) { create(:credential, server: foreign_server, name: "Foreign Credential") }

  def json_headers_for(api_key)
    {
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "allows cross-organization updates for management API keys" do
    patch "/api/v1/manage/credentials/#{foreign_credential.uuid}",
          params: { name: "Updated Credential", hold: true }.to_json,
          headers: json_headers_for(management_api_key.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    foreign_credential.reload
    expect(foreign_credential.name).to eq("Updated Credential")
    expect(foreign_credential.hold).to eq(true)
  end

  it "updates local credentials" do
    patch "/api/v1/manage/credentials/#{target_credential.uuid}",
          params: { name: "Scoped Updated", hold: true }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "name")).to eq("Scoped Updated")
    expect(json.dig("data", "credential", "hold")).to eq(true)

    target_credential.reload
    expect(target_credential.name).to eq("Scoped Updated")
    expect(target_credential.hold).to eq(true)
  end

  it "accepts numeric hold values on update" do
    patch "/api/v1/manage/credentials/#{target_credential.uuid}",
          params: { hold: 0 }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "hold")).to eq(false)
  end

  it "returns parameter-error when changing the key is not allowed" do
    patch "/api/v1/manage/credentials/#{target_credential.uuid}",
          params: { key: "new-key-value" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to include("Key cannot be changed").or include("key cannot be changed")
  end

  it "returns parameter-error for invalid hold value" do
    patch "/api/v1/manage/credentials/#{target_credential.uuid}",
          params: { hold: "not-a-boolean" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
