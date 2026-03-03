# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Credentials#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:target_credential) { create(:credential, server: server, name: "Original Credential", hold: false) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }
  let(:foreign_credential) { create(:credential, server: foreign_server, name: "Foreign Credential") }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "updates a credential inside credential scope" do
    patch "/api/v1/credentials/#{target_credential.uuid}",
          params: { name: "Updated Credential", hold: true }.to_json,
          headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "name")).to eq("Updated Credential")
    expect(json.dig("data", "credential", "hold")).to eq(true)

    target_credential.reload
    expect(target_credential.name).to eq("Updated Credential")
    expect(target_credential.hold).to eq(true)
  end

  it "blocks cross-organization updates for regular scoped credentials" do
    patch "/api/v1/credentials/#{foreign_credential.uuid}",
          params: { name: "Blocked Update" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end

  it "allows cross-organization updates for global-admin credentials" do
    patch "/api/v1/credentials/#{foreign_credential.uuid}",
          params: { name: "Global Updated", hold: true }.to_json,
          headers: json_headers_for(global_admin_credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "name")).to eq("Global Updated")
    expect(json.dig("data", "credential", "hold")).to eq(true)

    foreign_credential.reload
    expect(foreign_credential.name).to eq("Global Updated")
    expect(foreign_credential.hold).to eq(true)
  end

  it "returns parameter-error for invalid hold value" do
    patch "/api/v1/credentials/#{target_credential.uuid}",
          params: { hold: "not-a-boolean" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end

