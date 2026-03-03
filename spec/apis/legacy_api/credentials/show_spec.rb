# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Credentials#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end
  let(:string_false_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => "false" })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:target_credential) { create(:credential, server: server) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }
  let(:foreign_credential) { create(:credential, server: foreign_server) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns credential details inside the credential scope" do
    get "/api/v1/credentials/#{target_credential.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "uuid")).to eq(target_credential.uuid)
  end

  it "does not disclose credentials outside the credential scope" do
    get "/api/v1/credentials/#{foreign_credential.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end

  it "allows cross-organization credential reads for global-admin credentials" do
    get "/api/v1/credentials/#{foreign_credential.uuid}",
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "uuid")).to eq(foreign_credential.uuid)
  end

  it "does not treat string false as global access" do
    get "/api/v1/credentials/#{foreign_credential.uuid}",
        headers: { "X-Server-API-Key" => string_false_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end
end

